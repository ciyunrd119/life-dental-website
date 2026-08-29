require 'nokogiri'

module KnowledgeArchive
  class BodyNormalizer
    REMOVED_SELECTORS = [
      'header.meta', '.share-buttons', '.clearfix', '.info-banner',
      '.product-category', 'script', 'iframe', 'span.hide'
    ].freeze

    def self.call(html)
      new(html).call
    end

    def initialize(html)
      @fragment = Nokogiri::HTML::DocumentFragment.parse(html.to_s)
      @document = @fragment.document
    end

    def call
      return @fragment.to_html if @fragment.at_css('.know-article-content')

      clean_legacy_nodes
      nodes = expanded_children(@fragment).reject { |node| ignorable?(node) }
      heading_sections, preamble = build_heading_sections(nodes)

      content = element('div', class: 'know-article-content')
      lead = extract_lead(preamble)
      content.add_child(build_lead(lead)) if lead
      if heading_sections.empty? && meaningful_nodes?(preamble)
        heading_sections << build_fallback_section(preamble)
        preamble = []
      end
      content.add_child(build_untitled_section(preamble)) if meaningful_nodes?(preamble)
      heading_sections.each { |section| content.add_child(section[:node]) }

      output = Nokogiri::HTML::DocumentFragment.parse('')
      output.add_child(build_toc(heading_sections)) if heading_sections.any?
      output.add_child(content)
      output.to_html
    end

    private

    def clean_legacy_nodes
      @fragment.css(REMOVED_SELECTORS.join(',')).remove
      @fragment.css('a[href*="blogspot."]').each do |link|
        if clean_text(link.text).include?('莊禮駿')
          link['href'] = '../taichung/dr-chuang-li-chun.html'
          link.remove_attribute('target')
          next
        end

        container = link.ancestors('blockquote').first
        next unless container

        container.xpath('.//text()').each do |text_node|
          text_node.content = text_node.text.sub(/\s*同步發表於\s*\z/, '')
        end
        link.remove
      end
      @fragment.css('div.comment-content').each do |wrapper|
        wrapper.children.each { |child| wrapper.add_previous_sibling(child) }
        wrapper.remove
      end
      @fragment.css('p').each do |paragraph|
        if paragraph.at_css('img')
          figure = element('figure', class: 'know-image-placeholder')
          paragraph.css('img').each { |image| figure.add_child(image.unlink) }
          paragraph.add_previous_sibling(figure)
        end
        paragraph.remove if paragraph.text.gsub("\u00a0", '').strip.empty? && paragraph.css('img,table').empty?
      end
    end

    def expanded_children(parent)
      parent.children.to_a
    end

    def build_heading_sections(nodes)
      sections = []
      preamble = []
      current = nil

      nodes.each do |node|
        heading = heading_text(node)
        if heading
          current = {
            title: heading,
            node: element('section', class: 'know-section', id: "section-#{sections.length + 1}")
          }
          current[:node].add_child(text_element('h2', heading))
          sections << current
          append_heading_remainder(current[:node], node)
        elsif current
          current[:node].add_child(normalize_content_node(node))
        else
          preamble << normalize_content_node(node)
        end
      end

      [sections, preamble.compact]
    end

    def heading_text(node)
      if %w[h2 h3].include?(node.name)
        text = clean_text(node.text)
        return text unless text.empty?
        return
      end
      return unless node.name == 'blockquote'

      text = clean_text(node.text)
      return if text.empty? || text.length > 90
      return if text.match?(/醫師[：:]|治療內容[：:]|同步發表|(?:牙醫|植牙|全瓷).*,.*(?:牙醫|植牙|全瓷)/)
      return if node.at_css('img,table,ul,ol')

      text
    end

    def append_heading_remainder(section, source)
      heading = source.name == 'blockquote' ? source.at_css('h1,h2,h3,h4,h5,h6') : source
      heading&.css('img').to_a.each do |image|
        section.add_child(normalize_content_node(image))
      end
      return unless source.name == 'blockquote' && heading

      remainder = source.dup
      remainder.at_css('h1,h2,h3,h4,h5,h6')&.remove
      section.add_child(normalize_content_node(remainder)) if meaningful?(remainder)
    end

    def extract_lead(nodes)
      index = nodes.index do |node|
        node&.name == 'p' && !clean_text(node.text).empty? && node.css('img,table').empty?
      end
      return unless index

      nodes.delete_at(index)
    end

    def build_lead(paragraph)
      section = element('section', class: 'know-lead-box')
      section.add_child(paragraph)
      section
    end

    def build_untitled_section(nodes)
      section = element('section', class: 'know-section')
      nodes.each { |node| section.add_child(node) if meaningful?(node) }
      section
    end

    def build_fallback_section(nodes)
      section = element('section', class: 'know-section', id: 'section-1')
      section.add_child(text_element('h2', '文章重點'))
      nodes.each { |node| section.add_child(node) if meaningful?(node) }
      { title: '文章重點', node: section }
    end

    def build_toc(sections)
      nav = element('nav', class: 'know-article-toc', 'aria-label': '文章目錄')
      nav.add_child(text_element('div', '文章目錄', class: 'know-toc-label'))
      list = element('ol')
      sections.each do |section|
        item = element('li')
        link = text_element('a', section[:title], href: "##{section[:node]['id']}")
        item.add_child(link)
        list.add_child(item)
      end
      nav.add_child(list)
      nav
    end

    def normalize_content_node(node)
      return if ignorable?(node)

      node = node.unlink
      if node.name == 'img'
        figure = element('figure', class: 'know-image-placeholder')
        figure.add_child(node)
        return figure
      end

      if !node.css('img').empty? && clean_text(node.text).empty?
        figure = element('figure', class: 'know-image-placeholder')
        node.css('img').each { |image| figure.add_child(image.unlink) }
        return figure
      end

      if node.name == 'table'
        wrapper = element('div', class: 'know-table-wrap')
        wrapper.add_child(node)
        return wrapper
      end


      if node.name == 'blockquote' && clean_text(node.text).match?(/醫師[：:]|治療內容[：:]/)
        node.name = 'aside'
        node['class'] = 'know-doctor-note'
        node.children.first&.add_previous_sibling(text_element('span', '療程資料'))
        return node
      end

      node.name = 'h3' if %w[h4 h5 h6].include?(node.name)
      node
    end

    def meaningful_nodes?(nodes)
      nodes.any? { |node| meaningful?(node) }
    end

    def meaningful?(node)
      node && (!clean_text(node.text).empty? || node.at_css('img,table,ul,ol,a'))
    end

    def ignorable?(node)
      node.text? ? node.text.strip.empty? : node.name == 'br'
    end

    def clean_text(text)
      text.to_s.gsub("\u00a0", ' ').gsub(/\s+/, ' ').strip
    end

    def element(name, attributes = {})
      Nokogiri::XML::Node.new(name, @document).tap do |node|
        attributes.each { |key, value| node[key.to_s] = value }
      end
    end

    def text_element(name, text, attributes = {})
      element(name, attributes).tap { |node| node.content = text }
    end
  end
end
