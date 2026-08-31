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
    named_rules('Legacy 301')
  end

  def named_rules(prefix)
    all_rules.select { |rule| rule.attributes['name'].start_with?(prefix) }
  end

  def all_rules
    document = REXML::Document.new(File.read(WEB_CONFIG_PATH))
    REXML::XPath.match(document, '//system.webServer/rewrite/rules/rule')
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
      destination_file = if destination == '/'
                           'index.html'
                         elsif destination.end_with?('/')
                           "#{destination.delete_prefix('/')}index.html"
                         else
                           destination.delete_prefix('/')
                         end
      assert File.file?(File.join(PROJECT_ROOT, destination_file)), "missing target for #{source}: #{destination}"
      refute expanded_redirects.key?(destination), "redirect chain: #{source} -> #{destination}"
    end
  end

  def test_each_removed_url_has_one_gone_rule
    gone_rules = all_rules.select do |rule|
      action = REXML::XPath.first(rule, 'action')
      action.attributes['type'] == 'CustomResponse' && action.attributes['statusCode'] == '410'
    end
    assert_equal 34, gone_rules.length

    inventory.fetch('gone').each do |source|
      rules = matching_rules(source, gone_rules)
      assert_equal 1, rules.length, source
      action = REXML::XPath.first(rules.first, 'action')
      assert_equal 'Gone', action.attributes['statusReason'], source
    end
  end

  def test_unchanged_paths_match_no_migration_rule
    path_rules = named_rules('Canonical path') + named_rules('Legacy 301') + named_rules('Legacy 410')
    inventory.fetch('unchanged').each do |path|
      assert_empty matching_rules(path, path_rules), path
    end
  end

  def test_all_audited_urls_have_one_declared_outcome
    declared = expanded_redirects.keys + inventory.fetch('gone') + inventory.fetch('unchanged')
    assert_equal 136, declared.length
    assert_equal declared.length, declared.uniq.length
  end

  def test_canonical_path_redirects_are_exact_and_permanent
    expected = {
      '/index.html' => '/',
      '/taichung' => '/taichung/',
      '/taichung/index.html' => '/taichung/',
      '/zhushan' => '/zhushan/',
      '/zhushan/index.html' => '/zhushan/'
    }
    rules = named_rules('Canonical path') + named_rules('Legacy 301')
    expected.each do |source, destination|
      matches = matching_rules(source, rules)
      assert_equal 1, matches.length, source
      action = REXML::XPath.first(matches.first, 'action')
      assert_equal destination, action.attributes['url'], source
      assert_equal 'Permanent', action.attributes['redirectType'], source
      assert_equal 'true', action.attributes['appendQueryString'], source
    end
  end

  def test_host_rule_forces_https_www_but_excludes_appointment_app
    rule = named_rules('Canonical host').fetch(0)
    pattern = REXML::XPath.first(rule, 'match').attributes['url']
    assert Regexp.new(pattern, Regexp::IGNORECASE).match?('services/implant.html')
    refute Regexp.new(pattern, Regexp::IGNORECASE).match?('s/app/calendar.aspx')

    conditions = REXML::XPath.first(rule, 'conditions')
    assert_equal 'MatchAny', conditions.attributes['logicalGrouping']
    https, host = REXML::XPath.match(conditions, 'add')
    assert_equal ['{HTTPS}', '^OFF$', nil],
                 [https.attributes['input'], https.attributes['pattern'], https.attributes['negate']]
    assert_equal ['{HTTP_HOST}', '^www\.gracelife\.com\.tw$', 'true'],
                 [host.attributes['input'], host.attributes['pattern'], host.attributes['negate']]

    action = REXML::XPath.first(rule, 'action')
    assert_equal 'https://www.gracelife.com.tw/{R:1}', action.attributes['url']
    assert_equal 'Permanent', action.attributes['redirectType']
    assert_equal 'true', action.attributes['appendQueryString']
  end

  def test_legacy_clinic_redirects_go_directly_to_directory_canonicals
    assert_equal '/taichung/', expanded_redirects.fetch('/about-tc.html')
    assert_equal '/zhushan/', expanded_redirects.fetch('/about-js.html')
  end

  def test_rule_order_is_host_then_path_then_legacy_then_gone
    names = all_rules.map { |rule| rule.attributes['name'] }
    assert_operator names.index { |name| name.start_with?('Canonical host') }, :<,
                    names.index { |name| name.start_with?('Canonical path') }
    assert_operator names.index { |name| name.start_with?('Canonical path') }, :<,
                    names.index { |name| name.start_with?('Legacy 301') }
    assert_operator names.index { |name| name.start_with?('Legacy 301') }, :<,
                    names.index { |name| name.start_with?('Legacy 410') }
  end
end
