# Test form rendering
begin
  controller = AdminCustom::CategoriesController.new
  # Setup request context
  controller.request = ActionDispatch::TestRequest.create
  taxonomy = Spree::Taxonomy.new
  controller.instance_variable_set(:@taxonomy, taxonomy)
  
  lookup_context = ActionView::LookupContext.new(Rails.root.join('app/views'))
  view_context = ActionView::Base.with_empty_template_cache.new(lookup_context, { 'taxonomy' => taxonomy }, controller)
  # Include route helpers
  view_context.class.include Rails.application.routes.url_helpers
  
  html = view_context.render(partial: 'admin_custom/categories/form')
  puts "=== COMPILE TEST RESULT ==="
  puts "Form compiled successfully! Length: #{html.length}"
rescue => e
  puts "Compile error: #{e.message}"
  puts e.backtrace.join("\n")
end
