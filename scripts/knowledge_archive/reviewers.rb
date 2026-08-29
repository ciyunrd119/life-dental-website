module KnowledgeArchive
  module Reviewers
    PROFILES = {
      'all-on-4' => ['柳朝升醫師', '../zhushan/team/dr-liu-chao-sheng.html'],
      'implant' => ['柳朝升醫師', '../zhushan/team/dr-liu-chao-sheng.html'],
      'ortho' => ['許瑛祺醫師', '../taichung/dr-hsu-ying-chi.html'],
      'periodontal' => ['朱明輝醫師', '../taichung/dr-chu-ming-hui.html'],
      'prosthodontics' => ['莊禮駿醫師', '../taichung/dr-chuang-li-chun.html'],
      'esthetic' => ['莊禮駿醫師', '../taichung/dr-chuang-li-chun.html'],
      'general' => ['莊禮駿醫師', '../taichung/dr-chuang-li-chun.html']
    }.freeze

    module_function

    def profile(categories)
      category = Array(categories).find { |item| PROFILES.key?(item) } || 'general'
      PROFILES.fetch(category)
    end
  end
end
