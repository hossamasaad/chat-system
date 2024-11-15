class CreateMessages < ActiveRecord::Migration[7.1]
  def change
    create_table :messages do |t|
      t.references :chat, null: false, foreign_key: true
      t.integer :message_number, null: false
      t.text :message_content, null: false
      t.timestamps
    end

    add_index :messages, [:chat_id, :message_number], unique: true
  end
end
