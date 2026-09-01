require 'json'
require 'minitest/autorun'
require_relative '../scripts/breadcrumb_structured_data'

class BreadcrumbStructuredDataTest < Minitest::Test
  def breadcrumb_documents(html)
    html.scan(%r{<script type="application/ld\+json">\s*(.*?)\s*</script>}m)
        .flatten
        .map { |source| JSON.parse(source) }
        .select { |document| document['@type'] == 'BreadcrumbList' }
  end

  def test_service_page_publishes_home_and_current_page
    html = <<~HTML
      <html>
      <head></head>
      <body>
        <div class="page-breadcrumb-inner">
          <a href="../">Home</a><span>-</span><span>療程項目</span><span>-</span><span>數位植牙</span>
        </div>
        <h1>數位植牙</h1>
      </body>
      </html>
    HTML

    synced = BreadcrumbStructuredData.sync(
      html: html,
      canonical: 'https://www.gracelife.com.tw/services/implant.html'
    )

    expected = {
      '@context' => 'https://schema.org',
      '@type' => 'BreadcrumbList',
      'itemListElement' => [
        {
          '@type' => 'ListItem',
          'position' => 1,
          'name' => '首頁',
          'item' => 'https://www.gracelife.com.tw/'
        },
        {
          '@type' => 'ListItem',
          'position' => 2,
          'name' => '數位植牙'
        }
      ]
    }
    assert_equal [expected], breadcrumb_documents(synced)
  end

  def test_article_uses_h1_when_visible_breadcrumb_omits_the_current_page
    html = <<~HTML
      <html>
      <head></head>
      <body>
        <div class="page-breadcrumb-inner">
          <a href="../">Home</a><span>-</span><a href="../knowledge.html">牙醫知識</a>
        </div>
        <article><h1>DSD 數位微笑設計</h1></article>
      </body>
      </html>
    HTML

    synced = BreadcrumbStructuredData.sync(
      html: html,
      canonical: 'https://www.gracelife.com.tw/knowledge/dsd.html'
    )
    items = breadcrumb_documents(synced).first.fetch('itemListElement')

    assert_equal ['首頁', '牙醫知識', 'DSD 數位微笑設計'], items.map { |item| item['name'] }
    assert_equal 'https://www.gracelife.com.tw/knowledge.html', items[1]['item']
    refute items.last.key?('item')
  end

  def test_current_page_self_link_is_not_published_as_an_ancestor
    html = <<~HTML
      <html><head></head><body>
        <div class="page-breadcrumb-inner">
          <a href="../">Home</a><span>-</span><a href="./">台中旗艦店</a><span>-</span><span>診所資訊</span>
        </div>
        <h1>台中生活牙醫診所</h1>
      </body></html>
    HTML

    synced = BreadcrumbStructuredData.sync(
      html: html,
      canonical: 'https://www.gracelife.com.tw/taichung/'
    )
    items = breadcrumb_documents(synced).first.fetch('itemListElement')

    assert_equal ['首頁', '診所資訊'], items.map { |item| item['name'] }
  end

  def test_current_page_fragment_link_is_not_published_as_an_ancestor
    html = <<~HTML
      <html><head></head><body>
        <div class="page-breadcrumb-inner">
          <a href="../">Home</a><span>-</span><a href="./#details">台中旗艦店</a><span>-</span><span>診所資訊</span>
        </div>
        <h1>台中生活牙醫診所</h1>
      </body></html>
    HTML

    synced = BreadcrumbStructuredData.sync(
      html: html,
      canonical: 'https://www.gracelife.com.tw/taichung/'
    )
    items = breadcrumb_documents(synced).first.fetch('itemListElement')

    assert_equal ['首頁', '診所資訊'], items.map { |item| item['name'] }
  end

  def test_case_page_does_not_treat_a_specific_case_as_the_category_hub
    html = <<~HTML
      <html><head></head><body>
        <div class="page-breadcrumb-inner">
          <a href="../">Home</a><span>-</span><a href="all-on-4.html">案例分享</a><span>-</span><span>數位植牙實際案例</span>
        </div>
        <h1>數位植牙實際案例</h1>
      </body></html>
    HTML

    synced = BreadcrumbStructuredData.sync(
      html: html,
      canonical: 'https://www.gracelife.com.tw/cases/digital-implant.html'
    )
    items = breadcrumb_documents(synced).first.fetch('itemListElement')

    assert_equal ['首頁', '數位植牙實際案例'], items.map { |item| item['name'] }
  end

  def test_synchronization_is_idempotent
    html = <<~HTML
      <html><head></head><body>
        <div class="page-breadcrumb-inner"><a href="./">Home</a><span>-</span><span>預約諮詢</span></div>
        <h1>預約諮詢</h1>
      </body></html>
    HTML
    canonical = 'https://www.gracelife.com.tw/appointment.html'

    once = BreadcrumbStructuredData.sync(html: html, canonical: canonical)

    assert_equal once, BreadcrumbStructuredData.sync(html: once, canonical: canonical)
    assert_equal 1, breadcrumb_documents(once).length
  end

  def test_unmanaged_breadcrumb_schema_is_rejected
    html = <<~HTML
      <html><head>
      <script type="application/ld+json">
      {"@context":"https://schema.org","@type":"BreadcrumbList","itemListElement":[]}
      </script>
      </head><body>
        <div class="page-breadcrumb-inner"><a href="./">Home</a><span>-</span><span>預約諮詢</span></div>
        <h1>預約諮詢</h1>
      </body></html>
    HTML

    error = assert_raises(RuntimeError) do
      BreadcrumbStructuredData.sync(
        html: html,
        canonical: 'https://www.gracelife.com.tw/appointment.html'
      )
    end
    assert_match(/already contains BreadcrumbList/, error.message)
  end

  def test_current_page_name_is_required
    html = '<html><head></head><body><div class="page-breadcrumb-inner"><a href="./">Home</a></div></body></html>'

    error = assert_raises(RuntimeError) do
      BreadcrumbStructuredData.sync(
        html: html,
        canonical: 'https://www.gracelife.com.tw/appointment.html'
      )
    end
    assert_match(/current page name/, error.message)
  end

  def test_json_ld_escapes_html_script_delimiters_in_page_names
    html = <<~HTML
      <html><head></head><body>
        <div class="page-breadcrumb-inner"><a href="../">Home</a><span>-</span><a href="../knowledge.html">牙醫知識</a></div>
        <h1>Safety &lt;/script&gt;&lt;script&gt;alert(1)&lt;/script&gt;</h1>
      </body></html>
    HTML

    synced = BreadcrumbStructuredData.sync(
      html: html,
      canonical: 'https://www.gracelife.com.tw/knowledge/safety.html'
    )

    refute_includes synced, '"name": "Safety </script><script>alert(1)</script>"'
    current = breadcrumb_documents(synced).first.fetch('itemListElement').last
    assert_equal 'Safety </script><script>alert(1)</script>', current['name']
  end

  def test_ancestor_urls_must_be_https_and_same_site
    html = <<~HTML
      <html><head></head><body>
        <div class="page-breadcrumb-inner"><a href="https://example.com/">Home</a><span>-</span><span>預約諮詢</span></div>
        <h1>預約諮詢</h1>
      </body></html>
    HTML

    error = assert_raises(RuntimeError) do
      BreadcrumbStructuredData.sync(
        html: html,
        canonical: 'https://www.gracelife.com.tw/appointment.html'
      )
    end
    assert_match(/HTTPS URL on www\.gracelife\.com\.tw/, error.message)
  end
end
