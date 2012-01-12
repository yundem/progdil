
require 'pathname'                      #mutlak yol metodu
require 'pythonconfig'          #
require 'yaml'          #metodlar çağırıldı 

CONFIG = Config.fetch('presentation', {})       #ilgili slaytı(presentation) al

PRESENTATION_DIR = CONFIG.fetch('directory', 'p')     #slayttan dizinler alınmış
DEFAULT_CONFFILE = CONFIG.fetch('conffile', '_templates/presentation.cfg')      #
INDEX_FILE = File.join(PRESENTATION_DIR, 'index.html')  #slaytın indeksleri birleştirilmiş
IMAGE_GEOMETRY = [ 733, 550 ]   #image boyutları belirlenmiş
DEPEND_KEYS    = %w(source css js)      #bağımlılık için kullanılacak anahtarlar
DEPEND_ALWAYS  = %w(media)#bağımlılık dosyaları
TASKS = {       #görevler
    :index   => 'sunumları indeksle',       #
    :build   => 'sunumları oluştur',         #
    :clean   => 'sunumları temizle',          #
    :view    => 'sunumları görüntüle',         #
    :run     => 'sunumları sun',               #   verilen görevler ve görevlerinin ne olduğu belirtilmiş
    :optim   => 'resimleri iyileştir',        #
    :default => 'öntanımlı görev',           #
}                                           #

presentation   = {}
tag            = {}

class File    #sınıf                                                                         #  
  @@absolute_path_here = Pathname.new(Pathname.pwd)                                             #yolu sınıf değişkenine  atayıp
  def self.to_herepath(path)                                                                      #
    Pathname.new(File.expand_path(path)).relative_path_from(@@absolute_path_here).to_s              #path argümanı mutlak yapıldı, daha sonrada sınıf değişkenine
  end                                                                                                 # atadığımız yola göre göreceli yapıldı.
  def self.to_filelist(path)                                                                            # 
    File.directory?(path) ?                                                                           #
      FileList[File.join(path, '*')].select { |f| File.file?(f) } :                                 # 
      [path]                                                                                      #
  end                                                                                           #
end
    
def png_comment(file, string) #
  require 'chunky_png'          #metodlar çağrılarak 
  require 'oily_png'          #

  image = ChunkyPNG::Image.from_file(file) #
  image.metadata['Comment'] = 'raked'      #image'ler  biçimlendirilmiş
  image.save(file)                         #ve kaydedilmiş
end
def png_optim(file, threshold=40000)              #png uzantılı imagein boyutu sınırlandırılmış
  return if File.new(file).size < threshold       #ve bu boyuttan küçük olanların
  sh "pngnq -f -e .png-nq #{file}"                #uzantıları değiştirilmiş.yani  boyut küçültme işlemi yapılmış.
  out = "#{file}-nq"                              #
  if File.exist?(out)                               #dosyaların uzantıları nq ile bitiyorsa
    $?.success? ? File.rename(out, file) : File.delete(out) #nq kısmı silinmiş
  end
  png_comment(file, 'raked')                        #
end

def jpg_optim(file)                     # yukarıdaki gibi jpg uzantılı dosyaların boyutu küçültülmüş
  sh "jpegoptim -q -m80 #{file}"        #ve kalitesi(m80) belirlenmiş,
  sh "mogrify -comment 'raked' #{file}"  #biçim değiştirilmesi tamamlandığı belirtilmiş 
end

def optim                                                                  #
  pngs, jpgs = FileList["**/*.png"], FileList["**/*.jpg", "**/*.jpeg"]     #uzantılar değişkenlere atanmıi sırasıyla
                                                                           #ve optimize edilen bu uzantılar
  [pngs, jpgs].each do |a|                                                 #tek tek çekilmiş.
    a.reject! { |f| %x{identify -format '%c' #{f}} =~ /[Rr]aked/ }         #
  end                                                                      #
                                                                           #
  (pngs + jpgs).each do |f|                                                   #
    w, h = %x{identify -format '%[fx:w] %[fx:h]' #{f}}.split.map { |e| e.to_i }
    size, i = [w, h].each_with_index.max
    if size > IMAGE_GEOMETRY[i]                                                 #en başta belirlenen image_geometry boyutlarına
      arg = (i > 0 ? 'x' : '') + IMAGE_GEOMETRY[i].to_s                         #bakarak , büyükse boyut küçültmesi yapılmış
      sh "mogrify -resize #{arg} #{f}"
   end
  end

  pngs.each { |f| png_optim(f) }                                                #uzantılara bakarak hangi uzantının hangi fonksiyona göre
  jpgs.each { |f| jpg_optim(f) }                                                #kullanılacağı belirtilmiş. pngs'ler için png_optim , jpgs'ler için jpg_optim

  (pngs + jpgs).each do |f|                                                     #
    name = File.basename f                                                      #
    FileList["*/*.md"].each do |src|                                             #
      sh "grep -q '(.*#{name})' #{src} && touch #{src}"                          #
    end
  end
end

default_conffile = File.expand_path(DEFAULT_CONFFILE)           #yol kullanılarak yine en başta tanımlanan yapılandırma dosyasına erişilmiş.

FileList[File.join(PRESENTATION_DIR, "[^_.]*")].each do |dir|
  next unless File.directory?(dir)
  chdir dir do
    name = File.basename(dir)
    conffile = File.exists?('presentation.cfg') ? 'presentation.cfg' : default_conffile
    config = File.open(conffile, "r") do |f|
      PythonConfig::ConfigParser.new(f)
    end

    landslide = config['landslide']
    if ! landslide                                              #eğer landslide bölümü tanımlanmamışsa
      $stderr.puts "#{dir}: 'landslide' bölümü tanımlanmamış"   #hatayı basarak
      exit 1                                                    #çıkış yap
    end

    if landslide['destination']                                                         #eğer destination ayarı yapılmışsa 
      $stderr.puts "#{dir}: 'destination' ayarı kullanılmış; hedef dosya belirtilmeyin" #hatayı basarak 
      exit 1                                                                            #çıkış yap
    end

    if File.exists?('index.md')                 # slaytımızın kaynağı index.md ya da
      base = 'index'                            #
      ispublic = true                           #
    elsif File.exists?('presentation.md')       #  presentation.md olmalı
      base = 'presentation'                     #
      ispublic = false                          #
    else                                        #  aksi taktirde
      $stderr.puts "#{dir}: sunum kaynağı 'presentation.md' veya 'index.md' olmalı"#hatayı basarak
      exit 1									   #çıkış yap	
    end#

    basename = base + '.html'                    		# yukarıdaki şartlara bağlı olarak base'i .html uzantılı yapıyor
    thumbnail = File.to_herepath(base + '.png')  
    target = File.to_herepath(basename)          

    deps = []									              # kodumuzun en başındaki DEPEND_ALWAYS ve DEPEND_KEYS tanımlamalarından
    (DEPEND_ALWAYS + landslide.values_at(*DEPEND_KEYS)).compact.each do |v|                   #yararlanılarak bağımlılık yapılacak dizinler seçilmiş
      deps += v.split.select { |p| File.exists?(p) }.map { |p| File.to_filelist(p) }.flatten  #ve listeye atanmış.
    end

    deps.map! { |e| File.to_herepath(e) }   #oluşturulan liste yol kullanılarak göreceli yapılmış
    deps.delete(target)                     
    deps.delete(thumbnail)                  

    tags = []

   presentation[dir] = {
      :basename  => basename,   # üreteceğimiz sunum dosyasının baz adı
      :conffile  => conffile,   # landslide konfigürasyonu (mutlak dosya yolu)
      :deps      => deps,       # sunum bağımlılıkları
      :directory => dir,        # sunum dizini (tepe dizine göreli)
      :name      => name,       # sunum ismi
      :public    => ispublic,   # sunum dışarı açık mı
      :tags      => tags,       # sunum etiketleri
      :target    => target,     # üreteceğimiz sunum dosyası (tepe dizine göreli)
      :thumbnail => thumbnail,  # sunum için küçük resim
    }
  end
end

presentation.each do |k, v|   #slayttaki etiketlerin 
  v[:tags].each do |t|	      #		
    tag[t] ||= []             #her birini döngüyle
    tag[t] << k               #
  end                         #güncellemiş
end                           #

tasktab = Hash[*TASKS.map { |k, v| [k, { :desc => v, :tasks => [] }] }.flatten] #k ve v nin yapacağı görevler belirlenmiş ve hash le listelenmiş.

presentation.each do |presentation, data|           									#	
  ns = namespace presentation do											#
    file data[:target] => data[:deps] do |t|										#
      chdir presentation do												#
        sh "landslide -i #{data[:conffile]}"										#slayt oluşturulmuş(landslide -i)
        sh 'sed -i -e "s/^\([[:blank:]]*var hiddenContext = \)false\(;[[:blank:]]*$\)/\1true\2/" presentation.html'	#
        unless data[:basename] == 'presentation.html'									#slaytımızın adı presentation.html değilse
          mv 'presentation.html', data[:basename]									# adını presentation.html olarak değiştir.
        end
      end
    end

    file data[:thumbnail] => data[:target] do                                          #  
      next unless data[:public]                                                         #cutycapt komutu web sayfasının anahtarlarını oluşturuyor  
      sh "cutycapt " +                                                           	  # url , yükseklik , genişlik belirleniyor.
          "--url=file://#{File.absolute_path(data[:target])}#slide1 " +                	#
          "--out=#{data[:thumbnail]} " +                                              	#
          "--user-style-string='div.slides { width: 900px; overflow: hidden; }' " +      #
          "--min-width=1024 " +                                                            	#
          "--min-height=768 " +									#
          "--delay=1000"									#mogrify komutuyla küçük resimler optimize edilerek
      sh "mogrify -resize 240 #{data[:thumbnail]}"						#yeniden biçimlendiriliyor
      png_optim(data[:thumbnail])								#
    end

    task :optim do				#
      chdir presentation do                     #
        optim                                   #
      end
    end

    task :index => data[:thumbnail]                      #indeks belirleme görevi

    task :build => [:optim, data[:target], :index]       #inşa etme görevi

    task :view do                                                           #
      if File.exists?(data[:target])                                        #eğer elimizde görüntülencek yapı varsa onu
        sh "touch #{data[:directory]}; #{browse_command data[:target]}"     #tarayıcı komutuyla görüntülüyor
      else								 #ama yoksa önce inşa etmemimizi söylüyor
        $stderr.puts "#{data[:target]} bulunamadı; önce inşa edin"
      end
    end

    task :run => [:build, :view]  #önce inşa edip daha sonra görüntülüyor

    task :clean do			#
      rm_f data[:target]		#hedef ve
      rm_f data[:thumbnail]             #küçük resim silinmiş
    end

    task :default => :build             #
  end

  ns.tasks.map(&:to_s).each do |t|                  #görev listemize
    _, _, name = t.partition(":").map(&:to_sym)     #oluşturulan yeni görevler
    next unless tasktab[name]                       #eklenmiş
    tasktab[name][:tasks] << t                      #
  end
end

namespace :p do                               #isim uzayı içinde
  tasktab.each do |name, info|                # görev listemize bakarak 
    desc info[:desc]                           # yeni görevler
    task name => info[:tasks]                  # belirlenmiş
    task name[0] => name                       #
  end

  task :build do                                                                                    # 
    index = YAML.load_file(INDEX_FILE) || {}                                                        #slaytımızın indeksleri YAML dosyasına yüklenmiş
    presentations = presentation.values.select { |v| v[:public] }.map { |v| v[:directory] }.sort    #ve indeksleri seçerek sıralıyor.
    unless index and presentations == index['presentations']                                        # sunumun indekslerini belirlemiş
      index['presentations'] = presentations                                                        #
      File.open(INDEX_FILE, 'w') do |f|                                                             #ıNDEX_FıLE dosyası açmış ve içine index.to_yaml yazılmış
        f.write(index.to_yaml)                                                                      #
        f.write("---\n")                                                                            #
      end
    end
  end

  desc "sunum menüsü"          #desc rubyde açıklama yapmamımızı sağlar , burada da açıklama eklenmiş
  task :menu do                #
    lookup = Hash[			#
      *presentation.sort_by do |k, v|	#görev listemizi sıralamış
        File.mtime(v[:directory])	#
      end				#
      .reverse				#görev listemizi terslemiş(sıraladıktan  sonra)
      .map { |k, v| [v[:name], k] }	#
      .flatten				#
    ]					#
    name = choose do |menu|			#slayt seçilmiş
      menu.default = "1"			#ve
      menu.prompt = color(			#slaytın renklendirilmesi
        'Lütfen sunum seçin ', :headline	#yapılmış
      ) + '[' + color("#{menu.default}", :special) + ']'	#
      menu.choices(*lookup.keys)				#
    end
    directory = lookup[name]					#
    Rake::Task["#{directory}:run"].invoke			#Rake edilmiş
  end
  task :m => :menu						#menu görevi oluşturulmuş
end								#

desc "sunum menüsü"						#açıklama yapılmış
task :p => ["p:menu"]						#
task :presentation => :p					#
