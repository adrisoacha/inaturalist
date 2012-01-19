# Create a Darwin Core Archive from iNat observations

class FakeView < ActionView::Base
  include ActionView::Helpers::TagHelper
  include ActionView::Helpers::AssetTagHelper
  include ActionView::Helpers::UrlHelper
  include ActionController::UrlWriter
  
  @@default_url_options = {:host => APP_CONFIG[:site_url]}
  
  def initialize
    super
    self.view_paths = [File.join(RAILS_ROOT, 'app/views')]
  end
end

class Metadata < FakeView
  def initialize
    super
    @contact = INAT_CONFIG["general"]["contact"] || {}
    @extent = Observation.has_quality_grade(Observation::RESEARCH_GRADE).calculate(:extent, :geom)
    @start_date = Observation.has_quality_grade(Observation::RESEARCH_GRADE).minimum(:observed_on)
    @end_date = Observation.has_quality_grade(Observation::RESEARCH_GRADE).maximum(:observed_on)
  end
end

def make_metadata
  m = Metadata.new
  tmp_path = File.join(Dir::tmpdir, "metadata.eml.xml")
  open(tmp_path, 'w') do |f|
    f << m.render(:file => 'observations/gbif.eml.erb')
  end
  tmp_path
end

def make_descriptor
  d = FakeView.new
  tmp_path = File.join(Dir::tmpdir, "meta.xml")
  open(tmp_path, 'w') do |f|
    f << d.render(:file => 'observations/gbif.descriptor.builder')
  end
  tmp_path
end

def make_data
  headers = Observation::DARWIN_CORE_TERM_NAMES
  fname = "observations.csv"
  tmp_path = File.join(Dir::tmpdir, fname)
  
  find_options = {
    :include => [:taxon, :user, :photos, :quality_metrics, :identifications],
    :conditions => {:quality_grade => Observation::RESEARCH_GRADE}
  }
  
  FasterCSV.open(tmp_path, 'w') do |csv|
    csv << headers
    Observation.do_in_batches(find_options) do |lt|
      csv << headers.map{|h| lt.send(h)}
    end
  end
  
  tmp_path
end

def make_archive(*args)
  fname = "gbif-observations-dwca.tgz"
  tmp_path = File.join(Dir::tmpdir, fname)
  fnames = args.map{|f| File.basename(f)}
  system "cd #{Dir::tmpdir} && tar cvzf #{tmp_path} #{fnames.join(' ')}"
  tmp_path
end

metadata_path = make_metadata
puts "Metadata: #{metadata_path}"
descriptor_path = make_descriptor
puts "Descriptor: #{descriptor_path}"
data_path = make_data
puts "Data: #{data_path}"
archive_path = make_archive(metadata_path, descriptor_path, data_path)
puts "Archive: #{archive_path}"
FileUtils.mv(archive_path, "public/gbif-observations-dwca.tgz")
