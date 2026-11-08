# Preserve bcrypt hashes and existing users when moving from has_secure_password.
# encrypted_password uses the same bcrypt digest format as password_digest.
class MigrateUsersToDevise < ActiveRecord::Migration[8.1]
  def up
    add_column :users, :encrypted_password, :string, null: false, default: ""
    execute <<~SQL
      UPDATE users SET encrypted_password = password_digest
      WHERE password_digest IS NOT NULL
    SQL
    remove_column :users, :password_digest
  end

  def down
    add_column :users, :password_digest, :string
    execute <<~SQL
      UPDATE users SET password_digest = encrypted_password
      WHERE encrypted_password <> ''
    SQL
    change_column_null :users, :password_digest, false
    remove_column :users, :encrypted_password
  end
end
