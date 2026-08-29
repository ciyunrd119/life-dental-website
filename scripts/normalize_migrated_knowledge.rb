#!/usr/bin/env ruby

require 'nokogiri'
require_relative 'knowledge_archive/body_normalizer'

module KnowledgeArchive
  class MigratedPageNormalizer
    LEGACY_REMOVALS = BodyNormalizer::REMOVED_SELECTORS.join(',').freeze

    def self.call(path, source_body: nil)
      new(path, source_body: source_body).call
    end

    def initialize(path, source_body: nil)
      @path = path
      @source_body = source_body
    end

    def call
      original = File.read(@path)
      doc = Nokogiri::HTML(original)
      body = doc.at_css('.know-article-body')
      raise "missing .know-article-body: #{@path}" unless body
      return :unchanged if @source_body.nil? && body.at_css('.know-article-content')

      source = @source_body || body.inner_html
      expected = retained_content(source)
      normalized = BodyNormalizer.call(source)
      verify_preserved_content!(expected, normalized)
      body.inner_html = normalized

      html = doc.to_html.each_line.map { |line| line.gsub("\t", '  ').rstrip }.join("\n") + "\n"
      File.write(@path, html)
      :updated
    end

    private

    def retained_content(html)
      copy = Nokogiri::HTML::DocumentFragment.parse(html.to_s)
      copy.css(LEGACY_REMOVALS).remove
      copy.css('a[href*="blogspot."]').each do |link|
        link['href'] = '../taichung/dr-chuang-li-chun.html' if link.text.include?('莊禮駿')
      end
      copy.css('blockquote a[href*="blogspot."]').remove
      {
        images: copy.css('img[src]').map { |node| node['src'] },
        tables: copy.css('table').length,
        links: copy.css('a[href]').map { |node| node['href'] }
      }
    end

    def verify_preserved_content!(expected, normalized)
      output = Nokogiri::HTML::DocumentFragment.parse(normalized)
      actual_images = output.css('img[src]').map { |node| node['src'] }
      actual_links = output.css('a[href]').map { |node| node['href'] }

      missing_images = expected[:images].reject { |src| actual_images.include?(src) }
      missing_links = expected[:links].reject { |href| actual_links.include?(href) }
      raise "image loss in #{@path}: #{missing_images.join(', ')}" if missing_images.any?
      raise "table loss in #{@path}" if output.css('table').length < expected[:tables]
      raise "link loss in #{@path}: #{missing_links.join(', ')}" if missing_links.any?
    end
  end
end

if $PROGRAM_NAME == __FILE__
  root = File.expand_path('..', __dir__)
  pages = Dir[File.join(root, 'knowledge/know_*.html')].sort
  results = pages.map { |path| [path, KnowledgeArchive::MigratedPageNormalizer.call(path)] }
  updated = results.count { |(_, status)| status == :updated }
  unchanged = results.length - updated
  puts "Normalized #{updated} migrated knowledge pages; #{unchanged} unchanged."
end
