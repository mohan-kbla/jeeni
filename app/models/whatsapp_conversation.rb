class WhatsappConversation < ApplicationRecord
  serialize :metadata, type: Hash, coder: JSON

  has_many :messages, class_name: 'WhatsappMessage', foreign_key: 'wa_id', primary_key: 'wa_id', dependent: :destroy
  belongs_to :spree_order, class_name: 'Spree::Order', optional: true

  validates :wa_id, presence: true, uniqueness: true
  validates :phone_number, presence: true
  validates :state, presence: true

  STATES = %w[
    START
    ASK_PRODUCT
    ASK_NAME
    ASK_LOCATION
    ASK_ADDRESS
    ASK_ZIPCODE
    CONFIRM_ORDER
    CREATING_ORDER
    COMPLETED
    CANCELLED
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
