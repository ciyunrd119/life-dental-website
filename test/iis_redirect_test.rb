require 'minitest/autorun'
require 'rexml/document'
require 'rexml/xpath'
require 'yaml'
require_relative '../scripts/generate_iis_redirect_config'

class IisRedirectTest < Minitest::Test
  INVENTORY_PATH = File.expand_path('../config/iis_legacy_urls.yml', __dir__)
  PROJECT_ROOT = File.expand_path('..', __dir__)
  WEB_CONFIG_PATH = File.expand_path('../web.config', __dir__)

  def inventory
    @inventory ||= YAML.safe_load(File.read(INVENTORY_PATH))
  end

  def expanded_redirects
    same_date = inventory.fetch('same_date_knowledge').to_h do |date|
      ["/know_#{date}.html", "/knowledge/know_#{date}.html"]
    end
    inventory.fetch('fixed_redirects').merge(same_date).merge(inventory.fetch('renamed_knowledge'))
  end

  def redirect_rules
    document = REXML::Document.new(File.read(WEB_CONFIG_PATH))
    REXML::XPath.match(document, '//system.webServer/rewrite/rules/rule').select do |rule|
      REXML::XPath.first(rule, 'action').attributes['type'] == 'Redirect'
    end
  end

  def matching_rules(path, rules)
    relative_path = path.delete_prefix('/')
    rules.select do |rule|
      pattern = REXML::XPath.first(rule, 'match').attributes['url']
      Regexp.new(pattern, Regexp::IGNORECASE).match?(relative_path)
    end
  end

  def test_inventory_has_complete_audited_counts
    assert_equal 100, expanded_redirects.length
    assert_equal 34, inventory.fetch('gone').length
    assert_equal ['/', '/idea.html'], inventory.fetch('unchanged')
    assert_empty expanded_redirects.keys & inventory.fetch('gone')
    assert_empty expanded_redirects.keys & inventory.fetch('unchanged')
  end

  def test_generated_web_config_is_current
    assert_equal IisRedirectConfig.render(inventory), File.read(WEB_CONFIG_PATH)
  end

  def test_each_audited_redirect_has_one_permanent_direct_rule
    assert_equal 100, redirect_rules.length

    expanded_redirects.each do |source, destination|
      rules = matching_rules(source, redirect_rules)
      assert_equal 1, rules.length, source
      action = REXML::XPath.first(rules.first, 'action')
      assert_equal destination, action.attributes['url'], source
      assert_equal 'Permanent', action.attributes['redirectType'], source
      assert_equal 'true', action.attributes['appendQueryString'], source
    end
  end

  def test_redirect_destinations_exist_and_do_not_chain
    expanded_redirects.each do |source, destination|
      destination_file = destination == '/' ? 'index.html' : destination.delete_prefix('/')
      assert File.file?(File.join(PROJECT_ROOT, destination_file)), "missing target for #{source}: #{destination}"
      refute expanded_redirects.key?(destination), "redirect chain: #{source} -> #{destination}"
    end
  end
end
