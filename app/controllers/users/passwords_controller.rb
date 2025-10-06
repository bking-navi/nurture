class Users::PasswordsController < Devise::PasswordsController
  layout "auth", only: [:new, :create, :edit, :update]
end

