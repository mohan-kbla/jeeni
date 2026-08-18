class WhatsappChat < ApplicationRecord
  serialize :metadata, type: Hash, coder: JSON

  validates :phone_number, presence: true, uniqueness: true
  validates :state, presence: true

  STATES = %w[
    idle
    selecting_product
    entering_quantity
    entering_name
    entering_city
    entering_place
    entering_pincode
    confirming
    entering_detailed_address
    confirming_detailed
  ].freeze

  validates :state, inclusion: { in: STATES }

  after_initialize :set_default_metadata, if: :new_record?

  def update_metadata(key, value)
    self.metadata = (metadata || {}).merge(key.to_s => value)
    save!
  end

  def get_metadata(key)
    (metadata || {})[key.to_s]
  end

  def clear_metadata!
    self.metadata = {}
    save!
  end

  private

  def set_default_metadata
    self.metadata ||= {}
  end
end
