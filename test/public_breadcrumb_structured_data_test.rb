require 'json'
require 'minitest/autorun'
require 'uri'
require_relative '../scripts/sync_seo_metadata'

class PublicBreadcrumbStructuredDataTest < Minitest::Test
  ROOT = File.expand_path('..', __dir__)

  def schema_items(html)
    html.scan(%r{<script type="application/ld\+json">\s*(.*?)\s*</script>}m)
        .flatten
        .flat_map do |source|
          document = JSON.parse(source)
          documents = document.is_a?(Array) ? document : [document]
          documents.flat_map { |item| item.fetch('@graph', [item]) }
        end
  end

  def test_every_public_non_home_page_publishes_one_valid_breadcrumb_list
    paths = SeoMetadata.public_html_paths(ROOT) - ['index.html']
    assert_equal 124, paths.length

    paths.each do |path|
      html = File.read(File.join(ROOT, path))
      breadcrumbs = schema_items(html).select do |item|
        Array(item['@type']).include?('BreadcrumbList')
      end
      assert_equal 1, breadcrumbs.length, path

      items = breadcrumbs.first.fetch('itemListElement')
      assert_operator items.length, :>=, 2, path
      assert_equal (1..items.length).to_a, items.map { |item| item['position'] }, path
      assert items.all? { |item| item['name'].is_a?(String) && !item['name'].strip.empty? }, path

      items[0...-1].each do |item|
        uri = URI.parse(item.fetch('item'))
        assert_equal 'https', uri.scheme, path
        assert_equal 'www.gracelife.com.tw', uri.host, path
      end
      refute items.last.key?('item'), path
    end
  end
end
