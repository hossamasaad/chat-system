require "test_helper"

class MessagesControllerTest < ActionDispatch::IntegrationTest
  test "should get messages" do
    get messages_messages_url
    assert_response :success
  end

  test "should get index" do
    get messages_index_url
    assert_response :success
  end

  test "should get show" do
    get messages_show_url
    assert_response :success
  end

  test "should get update" do
    get messages_update_url
    assert_response :success
  end
end
