require 'minitest/autorun'
require 'tmpdir'
require 'fileutils'
require_relative '../scripts/import_knowledge_archive'

class KnowledgeArchiveRunnerTest < Minitest::Test
  class FixtureFetcher
    def initialize(responses)
      @responses = responses
    end

    def get(url)
      response = @responses[url]
      raise "HTTP 404: #{url}" unless response
      response
    end

    def download(url)
      get(url).b
    end
  end

  LIST_URL = 'https://www.gracelife.com.tw/know.html'

  def setup
    @temporary = Dir.mktmpdir
    @root = @temporary
    FileUtils.mkdir_p(File.join(@root, 'knowledge'))
    FileUtils.cp('knowledge/20231115-isq-implant-stability.html', File.join(@root, 'knowledge'))
    File.write(File.join(@root, 'knowledge.html'), '<html><body><div class="knowledge-card-grid"></div></body></html>')
  end

  def teardown
    FileUtils.remove_entry(@temporary)
  end

  def test_runner_downloads_assets_writes_page_and_is_idempotent
    first = runner.run(LIST_URL)
    second = runner.run(LIST_URL)
    assert_equal :created, first.fetch(0).status
    assert_equal :unchanged, second.fetch(0).status
    assert File.file?(File.join(@root, 'knowledge/know_20260506.html'))
    assert File.file?(File.join(@root, 'knowledge/img/20260506/1.jpg'))
  end

  def test_runner_reports_replacements_and_fetch_failures
    results = runner.run(LIST_URL)
    assert_includes results.map(&:status), :replaced
    failed = results.find { |result| result.status == :failed }
    assert_match(/HTTP 404/, failed.error)
  end

  private

  def runner
    list = <<~HTML
      <article><h3><a href="know_20260506.html">案例文章標題</a></h3><span>2026.05.06</span></article>
      <article><h3><a href="know_20231115.html">植牙穩固了沒 讓ISQ數據告訴你</a></h3><span>2023.11.15</span></article>
      <article><h3><a href="know_20250101.html">完全找不到的測試文章</a></h3><span>2025.01.01</span></article>
    HTML
    article = File.read('test/fixtures/knowledge_archive/article.html')
    responses = {
      LIST_URL => list,
      'https://www.gracelife.com.tw/know_20260506.html' => article,
      'https://www.gracelife.com.tw/images/about/know/20260506/1.jpg' => 'jpeg-bytes'
    }
    KnowledgeArchive::Runner.new(
      fetcher: FixtureFetcher.new(responses),
      overrides: {
        'know_20231115.html' => {
          'replacement' => 'knowledge/20231115-isq-implant-stability.html'
        }
      },
      root: @root,
      report_path: 'docs/reports/knowledge-archive-migration.md',
      write: true
    )
  end
end
