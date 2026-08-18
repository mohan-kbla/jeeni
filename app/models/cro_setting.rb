class CroSetting < ApplicationRecord
  validates :key, presence: true, uniqueness: true

  def self.get(key, default = nil)
    find_by(key: key.to_s)&.value || default
  end

  def self.set(key, value)
    setting = find_or_initialize_by(key: key.to_s)
    setting.value = value
    setting.save
  end
end
