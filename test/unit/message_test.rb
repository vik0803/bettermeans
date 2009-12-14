# Redmine - project management software
# Copyright (C) 2006-2009  Shereef Bishay
#

require File.dirname(__FILE__) + '/../test_helper'

class MessageTest < ActiveSupport::TestCase
  fixtures :projects, :roles, :members, :member_roles, :boards, :messages, :users, :watchers

  def setup
    @board = Board.find(1)
    @user = User.find(1)
  end
  
  def test_create
    topics_count = @board.topics_count
    messages_count = @board.messages_count
    
    message = Message.new(:board => @board, :subject => 'Test message', :content => 'Test message content', :author => @user)
    assert message.save
    @board.reload
    # topics count incremented
    assert_equal topics_count+1, @board[:topics_count]
    # messages count incremented
    assert_equal messages_count+1, @board[:messages_count]
    assert_equal message, @board.last_message
    # author should be watching the message
    assert message.watched_by?(@user)
  end
  
  def test_reply
    topics_count = @board.topics_count
    messages_count = @board.messages_count
    @message = Message.find(1)
    replies_count = @message.replies_count
    
    reply_author = User.find(2)
    reply = Message.new(:board => @board, :subject => 'Test reply', :content => 'Test reply content', :parent => @message, :author => reply_author)
    assert reply.save
    @board.reload
    # same topics count
    assert_equal topics_count, @board[:topics_count]
    # messages count incremented
    assert_equal messages_count+1, @board[:messages_count]
    assert_equal reply, @board.last_message
    @message.reload
    # replies count incremented
    assert_equal replies_count+1, @message[:replies_count]
    assert_equal reply, @message.last_reply
    # author should be watching the message
    assert @message.watched_by?(reply_author)
  end
  
  def test_moving_message_should_update_counters
    @message = Message.find(1)
    assert_no_difference 'Message.count' do
      # Previous board
      assert_difference 'Board.find(1).topics_count', -1 do
        assert_difference 'Board.find(1).messages_count', -(1 + @message.replies_count) do
          # New board
          assert_difference 'Board.find(2).topics_count' do
            assert_difference 'Board.find(2).messages_count', (1 + @message.replies_count) do
              @message.update_attributes(:board_id => 2)
            end
          end
        end
      end
    end
  end
  
  def test_destroy_topic
    message = Message.find(1)
    board = message.board
    topics_count, messages_count = board.topics_count, board.messages_count    
    
    assert_difference('Watcher.count', -1) do
      assert message.destroy
    end
    board.reload
    
    # Replies deleted
    assert Message.find_all_by_parent_id(1).empty?
    # Checks counters
    assert_equal topics_count - 1, board.topics_count
    assert_equal messages_count - 3, board.messages_count
    # Watchers removed
  end
  
  def test_destroy_reply
    message = Message.find(5)
    board = message.board
    topics_count, messages_count = board.topics_count, board.messages_count    
    assert message.destroy
    board.reload

    # Checks counters
    assert_equal topics_count, board.topics_count
    assert_equal messages_count - 1, board.messages_count
  end
  
  def test_editable_by
    message = Message.find(6)
    author = message.author
    assert message.editable_by?(author)
    
    author.roles_for_project(message.project).first.remove_permission!(:edit_own_messages)
    assert !message.reload.editable_by?(author.reload)
  end
  
  def test_destroyable_by
    message = Message.find(6)
    author = message.author
    assert message.destroyable_by?(author)
    
    author.roles_for_project(message.project).first.remove_permission!(:delete_own_messages)
    assert !message.reload.destroyable_by?(author.reload)
  end
  
  def test_set_sticky
    message = Message.new
    assert_equal 0, message.sticky
    message.sticky = nil
    assert_equal 0, message.sticky
    message.sticky = false
    assert_equal 0, message.sticky
    message.sticky = true
    assert_equal 1, message.sticky
    message.sticky = '0'
    assert_equal 0, message.sticky
    message.sticky = '1'
    assert_equal 1, message.sticky
  end
end


# == Schema Information
#
# Table name: messages
#
#  id            :integer         not null, primary key
#  board_id      :integer         not null
#  parent_id     :integer
#  subject       :string(255)     default(""), not null
#  content       :text
#  author_id     :integer
#  replies_count :integer         default(0), not null
#  last_reply_id :integer
#  created_on    :datetime        not null
#  updated_on    :datetime        not null
#  locked        :boolean         default(FALSE)
#  sticky        :integer         default(0)
#

