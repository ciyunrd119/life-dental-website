require 'date'
require 'nokogiri'
require 'yaml'

module KnowledgeArchive
  Article = Struct.new(
    :source_path, :title, :date, :candidates, :local_path,
    :replacement, :categories, keyword_init: true
  )

  module Catalog
    module_function

    def load_overrides(path)
      YAML.safe_load(File.read(path), permitted_classes: [], aliases: false) || {}
    end

    def parse(html, overrides:)
      Nokogiri::HTML(html).css('article').map do |node|
        title = node.at_css('h3').text.strip
        date = Date.strptime(node.text[/20\d{2}\.\d{1,2}\.\d{1,2}/], '%Y.%m.%d')
        links = node.css('a[href]').map { |a| a['href'] }.compact.uniq
        dated = "know_#{date.strftime('%Y%m%d')}.html"
        rule_key = ([dated] + links).find { |candidate| overrides.key?(candidate) }
        rule = rule_key ? overrides.fetch(rule_key) : {}
        source = rule['source_path'] || (links.include?(dated) ? dated : links.first)
        candidates = ([source, dated] + links).compact.uniq
        Article.new(
          source_path: source,
          title: title,
          date: date,
          candidates: candidates,
          local_path: rule['local_path'] || "knowledge/#{source}",
          replacement: rule['replacement'],
          categories: Array(rule['categories'])
        )
      end
    end
  end
end
