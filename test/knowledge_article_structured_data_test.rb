require 'cgi'
require 'date'
require 'json'
require 'minitest/autorun'
require 'uri'

class KnowledgeArticleStructuredDataTest < Minitest::Test
  ROOT = File.expand_path('..', __dir__)
  ARTICLE_PAGES = Dir.glob(File.join(ROOT, 'knowledge', '*.html')).sort.freeze
  ORGANIZATION = {
    '@type' => 'Organization',
    '@id' => 'https://www.gracelife.com.tw/#organization',
    'name' => '生活牙醫診所',
    'url' => 'https://www.gracelife.com.tw/'
  }.freeze
  PUBLISHER = ORGANIZATION.merge(
    'logo' => {
      '@type' => 'ImageObject',
      'url' => 'https://www.gracelife.com.tw/img/logo.png'
    }
  ).freeze

  def text(value)
    CGI.unescapeHTML(value.gsub(/<[^>]+>/, '').strip)
  end

  def page_facts(path)
    html = File.read(path)
    canonical = html.match(/<link rel="canonical" href="([^"]+)">/).captures.first
    description = text(html.match(/<meta name="description" content="([^"]+)">/).captures.first)
    headline = text(html.match(%r{<h1>(.*?)</h1>}m).captures.first)
    meta_html = html.match(%r{<div class="know-article-meta">(.*?)</div>}m).captures.first
    date = meta_html.match(%r{<span>(\d{4}\.\d{2}\.\d{2})</span>}).captures.first.tr('.', '-')
    reviewer = meta_html.match(%r{<a class="know-reviewer-link" href="([^"]+)">([^<]+)醫師</a>})
    tags_html = html.match(%r{<div class="know-article-tags"[^>]*>(.*?)</div>}m).captures.first
    tags = tags_html.scan(%r{<span>(.*?)</span>}m).flatten.map { |tag| text(tag) }
    article_html = html.match(%r{<article class="know-article">(.*?)</article>}m).captures.first
    image_path = article_html[%r{<img src="([^"]+)"}, 1]
    reviewer_url = URI.join(canonical, reviewer[1]).to_s

    {
      html: html,
      canonical: canonical,
      description: description,
      headline: headline,
      date: date,
      tags: tags,
      image: image_path && URI.join(canonical, image_path).to_s,
      image_file: image_path && File.expand_path(image_path, File.dirname(path)),
      reviewer_name: text(reviewer[2]),
      reviewer_url: reviewer_url,
      reviewer_file: File.expand_path(reviewer[1], File.dirname(path))
    }
  end

  def structured_data_documents(html)
    html.scan(%r{<script type="application/ld\+json">\s*(.*?)\s*</script>}m)
        .flatten
        .map { |script| JSON.parse(script) }
  end

  def schema_type?(item, type)
    Array(item['@type']).include?(type)
  end

  def test_all_knowledge_pages_publish_article_schema_matching_visible_content
    assert_equal 79, ARTICLE_PAGES.length
    assert_equal 'https', URI.parse(PUBLISHER.dig('logo', 'url')).scheme
    assert File.file?(File.join(ROOT, 'img', 'logo.png')), 'publisher logo 資產不存在'

    ARTICLE_PAGES.each do |path|
      facts = page_facts(path)
      Date.iso8601(facts[:date])
      assert File.file?(facts[:reviewer_file]), "#{path} 的審閱醫師頁不存在"
      reviewer_items = structured_data_documents(File.read(facts[:reviewer_file])).flat_map do |document|
        document.fetch('@graph', [document])
      end
      expected_reviewer_id = "#{facts[:reviewer_url]}#person"
      reviewer_person = reviewer_items.find do |item|
        schema_type?(item, 'Person') && item['@id'] == expected_reviewer_id
      end
      refute_nil reviewer_person, "#{path} 的審閱醫師 Person @id 不存在"
      assert_equal facts[:reviewer_name], reviewer_person['name'], path
      assert_equal facts[:reviewer_url], reviewer_person['url'], path

      documents = structured_data_documents(facts[:html])
      all_articles = documents.flat_map { |document| document.fetch('@graph', [document]) }
                              .select { |item| schema_type?(item, 'Article') }
      assert_equal 1, all_articles.length, "#{path} 應只包含一個 Article JSON-LD"
      article = all_articles.first
      article_documents = documents.select do |document|
        Array(document['@graph']).include?(article)
      end
      assert_equal 1, article_documents.length, "#{path} 的 Article 應位於一個 JSON-LD @graph"

      document = article_documents.first
      assert_equal 'https://schema.org', document['@context'], path
      assert_kind_of Array, document['@graph'], path
      web_pages = document['@graph'].select { |item| schema_type?(item, 'WebPage') }
      assert_equal 1, web_pages.length, "#{path} 應包含一個相連的 WebPage JSON-LD"

      web_page = web_pages.first
      assert_equal "#{facts[:canonical]}#article", article['@id'], path
      assert_equal facts[:canonical], article['url'], path
      assert_equal facts[:headline], article['headline'], path
      assert_equal facts[:description], article['description'], path
      assert_equal facts[:date], article['datePublished'], path
      refute article.key?('dateModified'), path
      assert_equal({ '@id' => facts[:canonical] }, article['mainEntityOfPage'], path)
      assert_equal facts[:tags], article['articleSection'], path
      assert_equal facts[:tags], article['keywords'], path
      assert_equal ORGANIZATION, article['author'], path
      assert_equal PUBLISHER, article['publisher'], path
      assert_equal(
        {
          '@type' => 'Person',
          '@id' => "#{facts[:reviewer_url]}#person",
          'name' => facts[:reviewer_name],
          'url' => facts[:reviewer_url]
        },
        web_page['reviewedBy'],
        path
      )
      assert_equal facts[:canonical], web_page['@id'], path
      assert_equal facts[:canonical], web_page['url'], path
      assert_equal({ '@id' => "#{facts[:canonical]}#article" }, web_page['mainEntity'], path)

      if facts[:image]
        assert_equal 'https', URI.parse(facts[:image]).scheme, path
        assert File.file?(facts[:image_file]), "#{path} 的文章圖片不存在"
        assert_equal facts[:image], article['image'], path
      else
        refute article.key?('image'), "#{path} 不應使用無關的共用圖片"
      end
    end
  end
end
