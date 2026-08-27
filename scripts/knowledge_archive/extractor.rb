require 'nokogiri'
require 'uri'

module KnowledgeArchive
  ImageRef = Struct.new(:source_url, :alt, :filename, keyword_init: true)
  ExtractedArticle = Struct.new(
    :title, :date_text, :summary, :body_html, :images, keyword_init: true
  )

  module Extractor
    module_function

    def call(html, base_url:)
      doc = Nokogiri::HTML(html)
      root = doc.at_css('article.post.single > section') || doc.at_css('article.post.single')
      raise 'article body not found' unless root
      root.css('script,style,iframe,form,nav,footer').remove
      title_node = root.at_css('h1,h2')
      raise 'article title not found' unless title_node
      title = title_node.text.strip
      title_node.remove
      date_text = root.text[/20\d{2}\.\d{1,2}\.\d{1,2}/]
      root.css('h1').each { |node| node.name = 'h2' }
      root.css('h2').drop(1).each { |node| node.name = 'h3' }
      images = root.css('img[src]').map do |img|
        absolute = URI.join(base_url, img['src']).to_s
        ImageRef.new(
          source_url: absolute,
          alt: img['alt'].to_s.strip,
          filename: File.basename(URI(absolute).path)
        )
      end
      root.css('img[src]').zip(images).each do |img, image_ref|
        img['src'] = image_ref.source_url
      end
      summary = root.css('p').map { |p| p.text.strip }.find { |text| !text.empty? }
      ExtractedArticle.new(
        title: title,
        date_text: date_text,
        summary: summary,
        body_html: root.inner_html.strip,
        images: images
      )
    end
  end
end
