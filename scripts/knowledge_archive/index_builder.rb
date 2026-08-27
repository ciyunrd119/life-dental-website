require 'cgi'
require 'date'
require 'nokogiri'
require_relative 'catalog'
require_relative 'categories'
require_relative 'extractor'

module KnowledgeArchive
  class IndexBuilder
    def initialize(path:)
      @path = path
    end

    def rebuild(entries:)
      doc = Nokogiri::HTML(File.read(@path))
      grid = doc.at_css('.knowledge-card-grid')
      grid.css('a.knowledge-card[data-migrated-source]').remove
      entries.each do |entry|
        href = entry.fetch(:article).local_path
        next if grid.css('a.knowledge-card').any? { |node| node['href'] == href }
        grid.add_child(card(**entry))
      end
      cards = grid.css('a.knowledge-card').select { |node| node.parent == grid }
      unique = cards.each_with_object({}) { |node, memo| memo[node['href']] ||= node }
      sorted = unique.values.sort_by do |node|
        Date.parse(node.at_css('time')['datetime'])
      end.reverse
      grid.children.remove
      sorted.each { |node| grid.add_child(node) }
      doc.to_html
    end

    def card(article:, extracted:, cover_path:)
      summary = extracted.summary.to_s.gsub(/\s+/, ' ').strip
      fragment = Nokogiri::HTML::DocumentFragment.parse(<<~HTML)
        <a href="#{CGI.escapeHTML(article.local_path)}" class="knowledge-card"
           data-knowledge-category="#{CGI.escapeHTML(article.categories.join(' '))}"
           data-migrated-source="#{CGI.escapeHTML(article.source_path)}">
          <figure class="knowledge-card-media">
            <img src="#{CGI.escapeHTML(cover_path)}" alt="#{CGI.escapeHTML(extracted.title)}">
          </figure>
          <div class="knowledge-card-body">
            <span class="knowledge-card-tag">#{Categories.label(article.categories.first)}</span>
            <h3>#{CGI.escapeHTML(extracted.title)}</h3>
            <p class="knowledge-card-desc">#{CGI.escapeHTML(summary)}<span class="knowledge-card-more">閱讀更多...</span></p>
            <time datetime="#{article.date.iso8601}">#{article.date.strftime('%Y.%m.%d')}</time>
          </div>
        </a>
      HTML
      fragment.at_css('a')
    end
  end
end
