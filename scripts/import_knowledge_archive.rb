#!/usr/bin/env ruby

require 'digest'
require 'fileutils'
require 'optparse'
require 'uri'
require_relative 'knowledge_archive/catalog'
require_relative 'knowledge_archive/categories'
require_relative 'knowledge_archive/extractor'
require_relative 'knowledge_archive/fetcher'
require_relative 'knowledge_archive/index_builder'
require_relative 'knowledge_archive/renderer'

module KnowledgeArchive
  Result = Struct.new(
    :source_path, :status, :local_path, :images_downloaded,
    :repaired_from, :error, keyword_init: true
  )

  class Runner
    def initialize(fetcher:, overrides:, root:, report_path:, write:)
      @fetcher = fetcher
      @overrides = overrides
      @root = root
      @report_path = report_path
      @write = write
      @renderer = Renderer.new(
        shell_path: File.join(root, 'knowledge/20231115-isq-implant-stability.html')
      )
      @index = IndexBuilder.new(path: File.join(root, 'knowledge.html'))
    end

    def run(list_url)
      catalog = Catalog.parse(@fetcher.get(list_url), overrides: @overrides)
      results = []
      entries = []
      catalog.each do |article|
        if article.replacement
          results << result(article, :replaced, local_path: article.replacement)
          next
        end
        begin
          extracted, accepted_url = resolve(article, list_url)
          article.categories = Categories.classify("#{article.title} #{extracted.body_html}")
          asset_map, cover_path, image_count = download_assets(article, extracted)
          html = @renderer.render(article: article, extracted: extracted, asset_map: asset_map)
          absolute_page = File.join(@root, article.local_path)
          status = @write ? Renderer.write(path: absolute_page, html: html) : :created
          entries << { article: article, extracted: extracted, cover_path: cover_path }
          results << result(
            article, status,
            local_path: article.local_path,
            images_downloaded: image_count,
            repaired_from: accepted_url.end_with?(article.source_path) ? nil : accepted_url
          )
        rescue StandardError => error
          results << result(article, :failed, error: error.message)
        end
      end
      if @write
        html = @index.rebuild(entries: entries)
        File.write(File.join(@root, 'knowledge.html'), html)
      end
      write_report(results)
      results
    end

    private

    def resolve(article, list_url)
      errors = []
      article.candidates.each do |candidate|
        url = URI.join(list_url, URI::DEFAULT_PARSER.escape(candidate)).to_s
        begin
          extracted = Extractor.call(@fetcher.get(url), base_url: url)
          return [extracted, url] if article.allow_title_mismatch ||
                                     title_match?(article.title, extracted.title)
          errors << "title mismatch: #{url}"
        rescue StandardError => error
          errors << error.message
        end
      end
      raise "no matching source page: #{article.candidates.join(', ')} (#{errors.uniq.join('; ')})"
    end

    def title_match?(listed, extracted)
      listed_tokens = normalized_tokens(listed)
      extracted_tokens = normalized_tokens(extracted)
      !(listed_tokens & extracted_tokens).empty?
    end

    def normalized_tokens(text)
      text.to_s
          .gsub(/[[:punct:]\s｜∣]+/, ' ')
          .scan(/[\p{Han}]{4,}|[A-Za-z0-9]{6,}/)
          .flat_map do |token|
            token.match?(/\A\p{Han}+\z/) ? token.chars.each_cons(4).map(&:join) : [token.downcase]
          end
          .uniq
    end

    def download_assets(article, extracted)
      date = article.date.strftime('%Y%m%d')
      directory = File.join(@root, 'knowledge/img', date)
      asset_map = {}
      extracted.images.each_with_index do |image, index|
        filename = safe_filename(image.filename, index)
        absolute = File.join(directory, filename)
        bytes = @fetcher.download(image.source_url)
        if @write
          FileUtils.mkdir_p(directory)
          same = File.exist?(absolute) &&
                 Digest::SHA256.file(absolute).hexdigest == Digest::SHA256.hexdigest(bytes)
          File.binwrite(absolute, bytes) unless same
        end
        asset_map[image.source_url] = "img/#{date}/#{filename}"
      end
      first = asset_map.values.first
      cover = first ? "knowledge/#{first}" : 'img/hero/knowledge.webp'
      [asset_map, cover, asset_map.length]
    end

    def safe_filename(filename, index)
      extension = File.extname(filename)
      stem = File.basename(filename, extension)
                 .encode('UTF-8', invalid: :replace, undef: :replace, replace: '')
                 .gsub(/[^A-Za-z0-9_-]+/, '-')
                 .gsub(/\A-+|-+\z/, '')
      stem = "image-#{index + 1}" if stem.empty?
      "#{stem}#{extension.downcase}"
    end

    def result(article, status, local_path: nil, images_downloaded: 0,
               repaired_from: nil, error: nil)
      Result.new(
        source_path: article.source_path,
        status: status,
        local_path: local_path,
        images_downloaded: images_downloaded,
        repaired_from: repaired_from,
        error: error
      )
    end

    def write_report(results)
      rows = results.map do |item|
        values = [item.source_path, item.status, item.local_path, item.images_downloaded,
                  item.repaired_from, item.error].map { |value| value.to_s.gsub('|', '\\|') }
        "| #{values.join(' | ')} |"
      end
      report = [
        '# 牙醫知識舊站搬運報告',
        '',
        '| Source | Status | Local page | Images | Repaired from | Error |',
        '|---|---|---|---:|---|---|',
        *rows,
        ''
      ].join("\n")
      return report unless @write
      absolute = File.join(@root, @report_path)
      FileUtils.mkdir_p(File.dirname(absolute))
      File.write(absolute, report)
      report
    end
  end
end

if $PROGRAM_NAME == __FILE__
  options = {
    source: 'https://www.gracelife.com.tw/know.html',
    site_root: Dir.pwd,
    report: 'docs/reports/knowledge-archive-migration.md',
    write: false
  }
  OptionParser.new do |parser|
    parser.on('--source URL') { |value| options[:source] = value }
    parser.on('--site-root PATH') { |value| options[:site_root] = File.expand_path(value) }
    parser.on('--report PATH') { |value| options[:report] = value }
    parser.on('--write') { options[:write] = true }
  end.parse!

  overrides = KnowledgeArchive::Catalog.load_overrides(
    File.join(__dir__, 'knowledge_archive_overrides.yml')
  )
  results = KnowledgeArchive::Runner.new(
    fetcher: KnowledgeArchive::Fetcher.new,
    overrides: overrides,
    root: options[:site_root],
    report_path: options[:report],
    write: options[:write]
  ).run(options[:source])
  counts = results.group_by(&:status).transform_values(&:length)
  images = results.sum(&:images_downloaded)
  puts "created=#{counts.fetch(:created, 0)} unchanged=#{counts.fetch(:unchanged, 0)} " \
       "replaced=#{counts.fetch(:replaced, 0)} failed=#{counts.fetch(:failed, 0)} images=#{images}"
end
