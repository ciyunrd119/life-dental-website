require 'json'
require 'minitest/autorun'
require 'uri'

class DoctorProfileStructuredDataTest < Minitest::Test
  ROOT = File.expand_path('..', __dir__)
  CLINIC_PAGES = {
    'taichung' => File.join(ROOT, 'taichung', 'index.html'),
    'zhushan' => File.join(ROOT, 'zhushan', 'index.html')
  }.freeze

  DOCTOR_PAGES = (
    Dir.glob(File.join(ROOT, 'taichung', 'dr-*.html')) +
    Dir.glob(File.join(ROOT, 'zhushan', 'team', 'dr-*.html'))
  ).sort.freeze

  def clinic_ids
    @clinic_ids ||= CLINIC_PAGES.transform_values do |path|
      items = structured_data_documents(File.read(path)).flat_map do |document|
        document.fetch('@graph', [document])
      end
      clinic = items.find { |item| schema_type?(item, 'Dentist') }
      raise "#{path} 缺少 Dentist JSON-LD" unless clinic

      clinic.fetch('@id')
    end
  end

  def page_facts(path)
    html = File.read(path)
    canonical = html.match(/<link rel="canonical" href="([^"]+)">/).captures.first
    title = html.match(%r{<title>([^<]+)</title>}).captures.first.strip
    description = html.match(/<meta name="description" content="([^"]+)">/).captures.first
    name = html.match(%r{<div class="doctor-profile-heading">.*?<h1>([^<]+)</h1>}m).captures.first.strip
    image_path = html.match(%r{<figure class="doctor-profile-photo[^>]*>.*?<img src="([^"]+)"}m).captures.first
    specialty_html = html.match(%r{<ul class="profile-specialty-list">(.*?)</ul>}m).captures.first
    specialties = specialty_html.scan(%r{<li>(.*?)</li>}m).flatten.map { |value| value.strip }
    clinic = path.include?('/taichung/') ? 'taichung' : 'zhushan'

    {
      html: html,
      canonical: canonical,
      title: title,
      description: description,
      name: name,
      image: URI.join(canonical, image_path).to_s,
      image_file: File.expand_path(image_path, File.dirname(path)),
      specialties: specialties,
      clinic_id: clinic_ids.fetch(clinic)
    }
  end

  def structured_data_documents(html)
    html.scan(%r{<script type="application/ld\+json">\s*(.*?)\s*</script>}m)
        .flatten
        .map { |script| JSON.parse(script) }
  end

  def schema_type?(item, type)
    Array(item['@type']).include?(type)
  end

  def test_all_fifteen_doctor_pages_publish_linked_profile_page_and_person_schema
    assert_equal 15, DOCTOR_PAGES.length

    DOCTOR_PAGES.each do |path|
      facts = page_facts(path)
      assert_equal 'https', URI.parse(facts[:image]).scheme, path
      assert File.file?(facts[:image_file]), "#{path} 的醫師照片不存在：#{facts[:image_file]}"

      documents = structured_data_documents(facts[:html])
      doctor_documents = documents.select do |document|
        Array(document['@graph']).any? do |item|
          schema_type?(item, 'ProfilePage') || schema_type?(item, 'Person')
        end
      end

      assert_equal 1, doctor_documents.length, "#{path} 的 ProfilePage 與 Person 應位於同一個 JSON-LD 文件"
      doctor_document = doctor_documents.first
      assert_equal 'https://schema.org', doctor_document['@context'], path
      assert_kind_of Array, doctor_document['@graph'], path

      items = doctor_document['@graph']
      profile_page = items.find { |item| schema_type?(item, 'ProfilePage') }
      person = items.find { |item| schema_type?(item, 'Person') }

      refute_nil profile_page, "#{path} 應包含 ProfilePage"
      refute_nil person, "#{path} 應包含 Person"

      expected_profile_id = "#{facts[:canonical]}#profilepage"
      expected_person_id = "#{facts[:canonical]}#person"

      assert_equal expected_profile_id, profile_page['@id'], path
      assert_equal facts[:title], profile_page['name'], path
      assert_equal facts[:canonical], profile_page['url'], path
      assert_equal facts[:description], profile_page['description'], path
      assert_equal({ '@id' => expected_person_id }, profile_page['mainEntity'], path)

      assert_equal expected_person_id, person['@id'], path
      assert_equal facts[:name], person['name'], path
      assert_equal '牙醫師', person['jobTitle'], path
      assert_equal facts[:canonical], person['url'], path
      assert_equal facts[:description], person['description'], path
      assert_equal facts[:image], person['image'], path
      assert_equal facts[:specialties], person['knowsAbout'], path
      assert_equal({ '@id' => facts[:clinic_id] }, person['worksFor'], path)
    end
  end
end
