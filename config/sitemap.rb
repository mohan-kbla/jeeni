# Set the host name for sitemaps
SitemapGenerator::Sitemap.default_host = "http://localhost:3000"

SitemapGenerator::Sitemap.create do
  # Put links creation here.
  #
  # The root path '/' and sitemap index file are added automatically for you.
  # Links are added to the Sitemap in the order they are specified.
  
  # Add catalog index page
  add '/products', changefreq: 'daily', priority: 0.9

  # Add blog index page
  add '/blogs', changefreq: 'weekly', priority: 0.7

  # Add all active products dynamically
  Spree::Product.active_products.find_each do |product|
    add "/products/#{product.slug}", lastmod: product.updated_at, changefreq: 'daily', priority: 0.8
  end

  # Add all published blog posts dynamically
  Blog.published.find_each do |blog|
    add "/blogs/#{blog.slug}", lastmod: blog.updated_at, changefreq: 'weekly', priority: 0.6
  end
end
