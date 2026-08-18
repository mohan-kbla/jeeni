module Spree
  module ProductDecorator
    def self.prepended(base)
      # Scopes
      base.scope :featured, -> { where(featured: true) }
      base.scope :active_products, -> { where(active: true) }
      base.scope :by_state, ->(state) { where(state: state) }
      base.scope :by_district, ->(district) { where(district: district) }
      
      # Additional validations
      base.validates :state, presence: true, allow_nil: true
      base.validates :district, presence: true, allow_nil: true

      # Reviews
      base.has_many :reviews, dependent: :destroy

      # FAQs & Testimonials for CRO
      base.has_many :faqs, class_name: "::Faq", foreign_key: :product_id, dependent: :destroy
      base.has_many :testimonials, class_name: "::Testimonial", foreign_key: :product_id, dependent: :destroy

      # Product Gallery
      base.has_one :product_gallery, dependent: :destroy
      base.accepts_nested_attributes_for :product_gallery, allow_destroy: true
      base.validates_presence_of :product_gallery
      base.after_initialize :build_default_gallery
      base.after_create :initialize_stock_items

      base.class_eval do
        def parsed_benefits
          return [] if benefits.blank?
          benefits.split("\n").map(&:strip).reject(&:empty?)
        end

        def parsed_ingredients
          return [] if ingredients.blank?
          ingredients.split("\n").map(&:strip).reject(&:empty?)
        end

        def parsed_how_to_use
          return [] if how_to_use.blank?
          how_to_use.split("\n").map(&:strip).reject(&:empty?)
        end

        delegate :karnataka_price, :karnataka_price=, to: :master, allow_nil: true
      end

      # Category Relation & Callbacks
      base.belongs_to :category, class_name: 'Spree::Taxonomy', foreign_key: :category_id, optional: true
      base.after_save :sync_category_taxons

      def build_default_gallery
        build_product_gallery if product_gallery.nil?
      end

      def initialize_stock_items
        Spree::StockLocation.active.each do |stock_location|
          stock_item = stock_location.stock_item(self.master) || stock_location.propagate_variant(self.master)
          if stock_item
            stock_item.set_count_on_hand(50)
          end
        end
      end

      def sync_category_taxons
        if saved_change_to_category_id?
          # 1. Remove classifications for any taxons of other taxonomies
          other_taxonomies = Spree::Taxonomy.where.not(id: category_id)
          other_taxon_ids = other_taxonomies.map { |t| t.root&.id }.compact
          
          if other_taxon_ids.any?
            self.taxons.delete(Spree::Taxon.where(id: other_taxon_ids))
          end
          
          # 2. Add the root taxon of the selected taxonomy if not already present
          if category_id.present?
            selected_category = Spree::Taxonomy.find_by(id: category_id)
            if selected_category && selected_category.root.present?
              unless self.taxons.include?(selected_category.root)
                self.taxons << selected_category.root
              end
            end
          end
        end
      end
    end
  end
end

Spree::Product.prepend Spree::ProductDecorator
