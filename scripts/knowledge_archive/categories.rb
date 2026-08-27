module KnowledgeArchive
  module Categories
    LABELS = {
      'all-on-4' => 'All-on-4',
      'prosthodontics' => '假牙贋復',
      'implant' => '數位植牙',
      'ortho' => '齒顎矯正',
      'esthetic' => '美容牙科',
      'periodontal' => '牙周治療',
      'general' => '一般牙科'
    }.freeze

    KEYWORDS = {
      'all-on-4' => %w[All-On-4 All-on-4 全口重建],
      'prosthodontics' => %w[假牙 全瓷冠 全鋯冠 貼片 齒雕 嵌體],
      'implant' => %w[植牙 植體 補骨 鼻竇增高 導引式],
      'ortho' => %w[矯正 隱適美 暴牙 齒列 反咬 阻生齒],
      'esthetic' => %w[美白 美學 貼片 牙縫 齒內美白],
      'periodontal' => %w[牙周 牙齦 牙根覆蓋 牙齦萎縮],
      'general' => %w[根管 蛀牙 洗牙 口腔]
    }.freeze

    module_function

    def label(category)
      LABELS.fetch(category, LABELS.fetch('general'))
    end

    def classify(text)
      matches = KEYWORDS.each_with_object([]) do |(category, keywords), found|
        found << category if keywords.any? { |keyword| text.include?(keyword) }
      end
      matches.empty? ? ['general'] : matches
    end
  end
end
