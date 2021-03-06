require 'test_helper'

class UsersSignupTest < ActionDispatch::IntegrationTest
  def setup
    ActionMailer::Base.deliveries.clear
  end
  
  test "invalid signup information" do
    get signup_path
    assert_no_difference 'User.count' do
    post users_path, params: { 
                        user: { fname:  "",
                            lname: "",
                            username: "",
                            email: "user@invalid",
                            password:              "foo",
                            password_confirmation: "bar" } }
    end
    assert_template 'users/new'
  end

  test "valid signup information without account activation emails" do
    settings(:setting_send_activation_emails).update_attribute(:value, '0') 
    get signup_path
    assert_difference 'User.count', 1 do
      post users_path, params: {
                            user: { fname:  "Example",
                               lname: "User",
                               username: "user_101",
                               email: "user@example.com",
                               password:              "password",
                               password_confirmation: "password" }}
    end
    user = assigns(:user)
    assert user.activated?
  end

  test "valid signup information with account activation" do
    get signup_path
    assert_difference 'User.count', 1 do
      post users_path, params: {
                            user: { fname:  "Example",
                               lname: "User",
                               username: "user_101",
                               email: "user@example.com",
                               password:              "password",
                               password_confirmation: "password" }}
    end
    assert_equal 1, ActionMailer::Base.deliveries.size
    user = assigns(:user)
    assert_not user.activated?
    # Try to log in before activation.
    log_in_as(user)
    assert_not is_logged_in?
    # Invalid activation token
    get edit_account_activation_path("invalid token")
    assert_not is_logged_in?
    # Valid token, wrong email
    get edit_account_activation_path(user.activation_token, email: 'wrong')
    assert_not is_logged_in?
    # Valid activation token
    get edit_account_activation_path(user.activation_token, email: user.email)
    assert user.reload.activated?
    follow_redirect!
    assert_template 'users/show'
    assert is_logged_in?
  end

  test "valid signup information with payment should go to checkout" do
    # Enable payment
    log_in_as(users(:example_user))
    settings(:require_payment).update_attribute(:value, '1')
    log_out

    get signup_path
    assert_difference 'User.count', 1 do
      post users_path, params: {
                            user: { fname:  "Example",
                               lname: "User",
                               username: "user_101",
                               email: "user@example.com",
                               password:              "password",
                               password_confirmation: "password" }}
    end
    # Pay
    follow_redirect!
    assert_template 'users/checkout'
    # Actual charge should be tested using your stripe keys manually
  end

  test "should redirect create when registration isn't active" do
    settings(:registration_active).update_attribute(:value, '0')
    get signup_path
    assert_no_difference 'User.count', 1 do
      post users_path, params: {
                            user: { fname:  "Example",
                               lname: "User",
                               username: "user_101",
                               email: "user@example.com",
                               password:              "password",
                               password_confirmation: "password" }}
    end
    assert_redirected_to root_url
  end
end
