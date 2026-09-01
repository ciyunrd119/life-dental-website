require 'minitest/autorun'
require 'pathname'
require 'rexml/document'
require 'rexml/xpath'
require_relative '../scripts/sync_seo_metadata'

class SeoMetadataTest < Minitest::Test
  ROOT = File.expand_path('..', __dir__)
  INDEX_DOCUMENTS = %w[index.html taichung/index.html zhushan/index.html].freeze

  def public_paths
    @public_paths ||= SeoMetadata.public_html_paths(ROOT)
  end

  def canonical_hrefs(path)
    File.read(File.join(ROOT, path)).scan(
      /<link\b(?=[^>]*\brel=["']canonical["'])(?=[^>]*\bhref=["']([^"']+)["'])[^>]*>/i
    ).flatten
  end

  def resolved_internal_href(document_path, href)
    path = href.split(/[?#]/, 2).first
    return path.delete_prefix('/') if path.start_with?('/')

    Pathname.new(File.dirname(document_path)).join(path).cleanpath.to_s
  end

  def test_public_page_inventory_is_complete_and_excludes_internal_files
    assert_equal 125, public_paths.length
    assert_includes public_paths, 'index.html'
    assert_includes public_paths, 'knowledge/know_20150222.html'
    assert_includes public_paths, 'services/implant.html'
    refute_includes public_paths, 'element.html'
    refute public_paths.any? { |path| path.start_with?('.vercel/', 'docs/', 'test/') }
  end

  def test_canonical_url_follows_the_approved_path_scheme
    assert_equal 'https://www.gracelife.com.tw/', SeoMetadata.canonical_url('index.html')
    assert_equal 'https://www.gracelife.com.tw/taichung/', SeoMetadata.canonical_url('taichung/index.html')
    assert_equal 'https://www.gracelife.com.tw/zhushan/', SeoMetadata.canonical_url('zhushan/index.html')
    assert_equal 'https://www.gracelife.com.tw/services/implant.html',
                 SeoMetadata.canonical_url('services/implant.html')
    assert_equal 'https://www.gracelife.com.tw/cases/index.html',
                 SeoMetadata.canonical_url('cases/index.html')
  end

  def test_canonical_url_rejects_non_public_paths
    assert_raises(ArgumentError) { SeoMetadata.canonical_url('element.html') }
    assert_raises(ArgumentError) { SeoMetadata.canonical_url('docs/plan.html') }
    assert_raises(ArgumentError) { SeoMetadata.canonical_url('services/implant') }
  end

  def test_every_public_page_has_one_self_referencing_canonical
    public_paths.each do |path|
      assert_equal [SeoMetadata.canonical_url(path)], canonical_hrefs(path), path
    end
  end

  def test_homepage_publishes_the_approved_search_title
    html = File.read(File.join(ROOT, 'index.html'))
    title = html.match(%r{<title>([^<]+)</title>}).captures.first

    assert_equal '生活牙醫診所｜台中南屯・南投竹山牙醫｜植牙・全瓷冠・矯正', title
  end

  def test_element_is_noindex_and_has_no_canonical
    html = File.read(File.join(ROOT, 'element.html'))
    assert_empty html.scan(/<link\b[^>]*\brel=["']canonical["'][^>]*>/i)
    robots = /<meta\b(?=[^>]*\bname=["']robots["'])(?=[^>]*\bcontent=["']noindex, nofollow["'])[^>]*>/i
    assert_equal 1, html.scan(robots).length
  end

  def test_sitemap_exactly_matches_public_canonicals
    document = REXML::Document.new(File.read(File.join(ROOT, 'sitemap.xml')))
    namespaces = { 'sitemap' => 'http://www.sitemaps.org/schemas/sitemap/0.9' }
    urls = REXML::XPath.match(document, '//sitemap:loc', namespaces).map(&:text)
    expected = public_paths.map { |path| SeoMetadata.canonical_url(path) }.sort
    assert_equal expected, urls.sort
    assert_equal 125, urls.uniq.length
    assert_empty REXML::XPath.match(document, '//sitemap:lastmod', namespaces)
  end

  def test_robots_declares_the_canonical_sitemap
    expected = "User-agent: *\nAllow: /\n\nSitemap: https://www.gracelife.com.tw/sitemap.xml\n"
    assert_equal expected, File.read(File.join(ROOT, 'robots.txt'))
  end

  def test_metadata_synchronization_is_idempotent
    html = "<html>\n<head>\n</head>\n</html>\n"
    once = SeoMetadata.sync_canonical(html, 'https://www.gracelife.com.tw/test.html')
    assert_equal once, SeoMetadata.sync_canonical(once, 'https://www.gracelife.com.tw/test.html')

    element_once = SeoMetadata.sync_element_robots(html)
    assert_equal element_once, SeoMetadata.sync_element_robots(element_once)
  end

  def test_public_pages_do_not_link_to_index_documents
    public_paths.each do |document_path|
      html = File.read(File.join(ROOT, document_path))
      hrefs = html.scan(/\bhref=["']([^"']+)["']/i).flatten
      duplicate_links = hrefs.select do |href|
        next false if href.match?(%r{\A(?:[a-z][a-z0-9+.-]*:|//|#)}i)

        INDEX_DOCUMENTS.include?(resolved_internal_href(document_path, href))
      end
      assert_empty duplicate_links, "#{document_path}: #{duplicate_links.join(', ')}"
    end
  end

  def test_index_link_normalization_preserves_query_and_fragment
    html = '<a href="../taichung/index.html?src=nav#team">Clinic</a>'
    expected = '<a href="../taichung/?src=nav#team">Clinic</a>'
    assert_equal expected, SeoMetadata.normalize_index_links(html, 'services/implant.html')
  end

  def test_index_link_normalization_keeps_root_relative_style
    html = '<a href="/zhushan/index.html#team">Clinic</a>'
    expected = '<a href="/zhushan/#team">Clinic</a>'
    assert_equal expected, SeoMetadata.normalize_index_links(html, 'services/implant.html')
  end
end
