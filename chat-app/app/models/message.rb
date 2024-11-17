class Message < ApplicationRecord
  include Elasticsearch::Model
  include Elasticsearch::Model::Callbacks

  belongs_to :chat
  validates :message_number, presence: true, uniqueness: { scope: :chat_id }
  validates :message_content, presence: true

  settings index: { 
    number_of_shards: 1,
    analysis: {
      filter: {
        ngram_filter: {
          type: "ngram",
          min_gram: 3,
          max_gram: 3
        }
      },
      analyzer: {
        ngram_analyzer: {
          type: "custom",
          tokenizer: "standard",
          filter: ["lowercase", "asciifolding", "ngram_filter"]
        }
      }
    }
  } do
    mappings dynamic: false do
      indexes :message_content, type: :text, analyzer: "ngram_analyzer"
      indexes :chat_id, type: :integer
    end
  end

  def as_indexed_json(options = nil)
    self.as_json(only: [:chat_id, :message_content])
  end  

  def self.search(chat_id, content)
    params = {
      query: {
        bool: {
          must: [
            { term: { chat_id: chat_id } },
            { wildcard: { message_content: "*#{content.downcase}*" } } # Match for case-insensitive search
          ]
        }
      }
    }
    self.__elasticsearch__.search(params).records
  end
end