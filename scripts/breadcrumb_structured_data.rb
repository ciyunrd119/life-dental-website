require 'json'
require 'nokogiri'
require 'uri'

module BreadcrumbStructuredData
  BEGIN_MARKER = '<!-- BEGIN AUTO-GENERATED BREADCRUMB JSON-LD -->'.freeze
  END_MARKER = '<!-- END AUTO-GENERATED BREADCRUMB JSON-LD -->'.freeze
  SEPARATOR = '-'.freeze
  VIRTUAL_ANCESTOR_NAMES = ['療程項目', '關於我們', '案例分享'].freeze
  MANAGED_BLOCK = %r{#{Regexp.escape(BEGIN_MARKER)}.*?#{Regexp.escape(END_MARKER)}\n?}m

  module_function

  def sync(html:, canonical:)
    html = html.gsub(MANAGED_BLOCK, '')
    doc = Nokogiri::HTML(html)
    if doc.css('script[type="application/ld+json"]').any? { |script| contains_breadcrumb?(script.text) }
      raise 'HTML already contains BreadcrumbList outside the managed block'
    end
    breadcrumb = doc.at_css('.page-breadcrumb-inner')
    raise 'HTML is missing .page-breadcrumb-inner' unless breadcrumb

    nodes = breadcrumb.element_children.reject do |node|
      node.name == 'span' && node.text.strip == SEPARATOR
    end
    last_node = nodes.last
    last_url = URI.join(canonical, last_node['href']).to_s if last_node&.name == 'a'
    if last_node&.name != 'a' || same_document?(last_url, canonical)
      current_name = normalized_name(last_node)
      ancestor_nodes = nodes[0...-1]
    else
      current_name = normalized_name(doc.at_css('h1'))
      ancestor_nodes = nodes
    end
    raise 'HTML is missing a current page name' if current_name.empty?

    items = ancestor_nodes.each_with_object([]) do |node, result|
      name = node.text.strip.gsub(/\s+/, ' ')
      next if name.empty? || node.name != 'a'
      next if VIRTUAL_ANCESTOR_NAMES.include?(name)
      item_url = URI.join(canonical, node['href']).to_s
      next if same_document?(item_url, canonical)
      item_uri = URI.parse(item_url)
      unless item_uri.scheme == 'https' && item_uri.host == 'www.gracelife.com.tw'
        raise "breadcrumb ancestor must use an HTTPS URL on www.gracelife.com.tw: #{item_url}"
      end

      item = {
        '@type' => 'ListItem',
        'position' => 0,
        'name' => name == 'Home' ? '首頁' : name
      }
      item['item'] = item_url
      result << item
    end
    items << {
      '@type' => 'ListItem',
      'position' => 0,
      'name' => current_name
    }
    raise 'BreadcrumbList requires at least two ListItems' if items.length < 2
    items.each_with_index { |item, index| item['position'] = index + 1 }

    schema = {
      '@context' => 'https://schema.org',
      '@type' => 'BreadcrumbList',
      'itemListElement' => items
    }
    json = JSON.pretty_generate(schema)
               .gsub('&', '\\u0026')
               .gsub('<', '\\u003c')
               .gsub('>', '\\u003e')
    block = <<~HTML
      #{BEGIN_MARKER}
      <script type="application/ld+json">
      #{json}
      </script>
      #{END_MARKER}
    HTML
    raise 'HTML is missing </head>' unless html.match?(%r{</head>}i)

    html.sub(%r{</head>}i, "#{block}</head>")
  end

  def normalized_name(node)
    node&.text.to_s.strip.gsub(/\s+/, ' ')
  end

  def same_document?(left, right)
    [left, right].map do |url|
      uri = URI.parse(url)
      uri.query = nil
      uri.fragment = nil
      uri.to_s
    end.uniq.length == 1
  end

  def contains_breadcrumb?(source)
    documents = JSON.parse(source)
    documents = [documents] unless documents.is_a?(Array)
    documents.any? do |document|
      items = document.is_a?(Hash) ? document.fetch('@graph', [document]) : []
      items.any? { |item| Array(item['@type']).include?('BreadcrumbList') }
    end
  end
end
