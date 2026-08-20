require 'minitest/autorun'

class KnowledgeDoctorNoteStyleTest < Minitest::Test
  def test_doctor_note_uses_readable_desktop_and_mobile_type_sizes
    css = File.read('css/style.css')

    assert_match(/\.know-doctor-note p\{font-size:18px;/, css)
    assert_match(/@media\(max-width:900px\).*?\.know-doctor-note p\{font-size:16px;\}/m, css)
  end

  def test_component_library_documents_the_responsive_type_sizes
    element = File.read('element.html')

    assert_includes element, '內文字級：桌機 18px／手機 16px'
  end
end
