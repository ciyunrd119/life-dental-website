require 'minitest/autorun'
require 'yaml'

class IisRedirectTest < Minitest::Test
  INVENTORY_PATH = File.expand_path('../config/iis_legacy_urls.yml', __dir__)

  def inventory
    @inventory ||= YAML.safe_load(File.read(INVENTORY_PATH))
  end

  def expanded_redirects
    same_date = inventory.fetch('same_date_knowledge').to_h do |date|
      ["/know_#{date}.html", "/knowledge/know_#{date}.html"]
    end
    inventory.fetch('fixed_redirects').merge(same_date).merge(inventory.fetch('renamed_knowledge'))
  end

  def test_inventory_has_complete_audited_counts
    assert_equal 100, expanded_redirects.length
    assert_equal 34, inventory.fetch('gone').length
    assert_equal ['/', '/idea.html'], inventory.fetch('unchanged')
    assert_empty expanded_redirects.keys & inventory.fetch('gone')
    assert_empty expanded_redirects.keys & inventory.fetch('unchanged')
  end
end
