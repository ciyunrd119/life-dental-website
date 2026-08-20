require 'json'
require 'minitest/autorun'

class HomepageStructuredDataTest < Minitest::Test
  def setup
    html = File.read('index.html')
    json = html.match(%r{<script type="application/ld\+json">\s*(.*?)\s*</script>}m)

    refute_nil json, '首頁應包含 JSON-LD'
    data = JSON.parse(json[1])
    @organization = data.fetch('@graph').find do |item|
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
      { '@id' => 'https://www.gracelife.com.tw/zushan/#localbusiness' }
    ]

    assert_equal expected_departments, @organization['department']
    refute @organization.key?('subOrganization')
  end
end
