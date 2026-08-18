# config/initializers/spree_mariadb_patch.rb
# Fixes compatibility issue with ActiveRecord::TypedStore on MariaDB 10.5.
# On MariaDB, JSON columns are resolved as LONGTEXT, mapping to ActiveRecord::Type::Text.
# This causes TypedStore's IdentityCoder to bypass serialization and pass raw Hash to SQL quoting,
# raising "TypeError: can't quote Hash". This patch forces JSON serialization when the subtype is Text.

ActiveSupport.on_load(:active_record) do
  if defined?(ActiveRecord::TypedStore::Type)
    ActiveRecord::TypedStore::Type.class_eval do
      def serialize(value)
        if subtype.is_a?(ActiveRecord::Type::Text)
          value.is_a?(Hash) ? value.to_json : super(value)
        else
          super(value)
        end
      end
    end
  end
end

# Disable Spree webhooks globally to prevent MariaDB compatibility issue with "MEMBER OF" syntax
ENV['DISABLE_SPREE_WEBHOOKS'] = 'true'

