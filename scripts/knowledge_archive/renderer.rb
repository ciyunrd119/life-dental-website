require 'fileutils'
require 'nokogiri'
require_relative 'catalog'
require_relative 'categories'
require_relative 'extractor'

module KnowledgeArchive
  class ExistingManualFile < StandardError; end

  class Renderer
    def initialize(shell_path:)
      @shell_path = shell_path
    end

    def render(article:, extracted:, asset_map:)
      doc = Nokogiri::HTML(File.read(@shell_path))
      doc.at_css('title').content = "#{extracted.title}｜生活牙醫診所"
      doc.at_css('meta[name="description"]')['content'] = extracted.summary.to_s
      breadcrumb = doc.at_css('.page-breadcrumb-inner')
      breadcrumb.add_child('<span>-</span>')
      breadcrumb.add_child(Nokogiri::XML::Node.new('span', doc).tap { |node| node.content = extracted.title })
      doc.at_css('.know-article-hero h1').content = extracted.title
      tags = doc.at_css('.know-article-tags')
      tags.children.remove
      ['牙醫知識', Categories.label(article.categories.first)].each do |label|
        tags.add_child(Nokogiri::XML::Node.new('span', doc).tap { |node| node.content = label })
      end
      meta = doc.css('.know-article-meta span')
      meta[0].content = article.date.strftime('%Y.%m.%d')
      meta[-1].content = Categories.label(article.categories.first)
      body = doc.at_css('.know-article-body')
      body.children.remove
      fragment = Nokogiri::HTML::DocumentFragment.parse(extracted.body_html)
      fragment.css('img[src]').each do |img|
        img['src'] = asset_map.fetch(img['src'])
        img['alt'] = extracted.title if img['alt'].to_s.strip.empty?
      end
      body.add_child(fragment)
      hero_image = doc.at_css('.know-article-media img')
      if hero_image && asset_map.any?
        hero_image['src'] = asset_map.values.first
        hero_image['alt'] = extracted.title
      else
        doc.at_css('.know-article-media')&.remove
      end
      cta = doc.at_css('.cta-section')
      cta.at_css('.cta-title').inner_html = '有牙齒問題，歡迎<em>預約諮詢</em>' if cta
      cta.at_css('.cta-desc').content = '由醫師依您的口腔狀況進行評估，說明合適的檢查與治療安排。' if cta
      doc.at_css('body')['data-migrated-source'] = article.source_path
      doc.to_html
    end

    def self.write(path:, html:)
      if File.exist?(path)
        current = File.read(path)
        return :unchanged if current == html
        raise ExistingManualFile unless current.include?('data-migrated-source=')
      end
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, html)
      :created
    end

  end
end
