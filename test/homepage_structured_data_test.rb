require 'json'
require 'minitest/autorun'

class HomepageStructuredDataTest < Minitest::Test
  def setup
    html = File.read('index.html')
    json = html.match(%r{<script type="application/ld\+json">\s*(.*?)\s*</script>}m)

    refute_nil json, '首頁應包含 JSON-LD'
    data = JSON.parse(json[1])
    @graph = data.fetch('@graph')
    @organization = @graph.find do |item|
      item['@id'] == 'https://www.gracelife.com.tw/#organization'
    end
    refute_nil @organization, '首頁 JSON-LD 應包含生活牙醫組織'
  end

  def test_organization_publishes_all_clinic_social_profiles
    expected_profiles = [
      'https://www.facebook.com/ilovegracelife/',
      'https://www.instagram.com/gracelife520',
      'https://www.youtube.com/@52gracelife',
      'https://www.facebook.com/gracelifenantou/',
      'https://www.instagram.com/gracelife_nantou/',
      'https://line.me/ti/p/%40dhh1667m'
    ]

    assert_equal expected_profiles, @organization['sameAs']
  end

  def test_organization_references_both_clinic_departments
    expected_departments = [
      { '@id' => 'https://www.gracelife.com.tw/taichung/#localbusiness' },
      { '@id' => 'https://www.gracelife.com.tw/zhushan/#localbusiness' }
    ]

    assert_equal expected_departments, @organization['department']
    refute @organization.key?('subOrganization')
  end

  def test_website_publishes_the_official_site_name
    website = @graph.find { |item| item['@id'] == 'https://www.gracelife.com.tw/#website' }

    refute_nil website, '首頁 JSON-LD 應包含 WebSite'
    assert_equal 'WebSite', website['@type']
    assert_equal 'https://www.gracelife.com.tw/', website['url']
    assert_equal '生活牙醫診所', website['name']
    assert_equal 'Grace Life Dental Clinic', website['alternateName']
    assert_equal({ '@id' => 'https://www.gracelife.com.tw/#organization' }, website['publisher'])
  end
end
