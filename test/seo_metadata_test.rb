require 'minitest/autorun'
require_relative '../scripts/sync_seo_metadata'

class SeoMetadataTest < Minitest::Test
  ROOT = File.expand_path('..', __dir__)

  def public_paths
    @public_paths ||= SeoMetadata.public_html_paths(ROOT)
  end

  def test_public_page_inventory_is_complete_and_excludes_internal_files
    assert_equal 127, public_paths.length
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
end
