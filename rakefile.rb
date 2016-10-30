require 'rake/clean'

CLEAN.include FileList.new('titles/t_*.txt')
CLEAN.include FileList.new('titles/t_*.png')
CLEAN.include FileList.new('nombres/n_*.png')
CLEAN.include FileList.new('tmp/*')
CLOBBER.include FileList.new('build/*')
CLOBBER.include FileList.new('build_a5/*')

def page_range
  unless @page_range
    head, tail = (ENV['p'] || '1-8').split(/\-/)
    tail ||= head
    @page_range = (head.to_i .. tail.to_i)
  end
  @page_range
end

task default: :all

multitask :all => page_range.collect {|i| 'build/p%03d.png' % i}

multitask :a5  => page_range.collect {|i| 'build_a5/p%03d.png' % i}

task :pdf do |t|
  sh 'convert -page a5 -define pdf:page-direction=right-to-left build/p*.png build/pages.pdf'
end

task :a5pdf => :a5 do |t|
  files = page_range.collect {|i| 'build_a5/p%03d.png' % i}.join ' '
  range = ('%03d' % page_range.first) + '-' + ('%03d' % page_range.last)
  sh "convert -page a5 -extent 3390x4724 -define pdf:page-direction=right-to-left #{files} build_a5/pages_#{range}.pdf"
end

directory 'tmp'

task :a5book => [:a5, 'tmp/blank_page.png', 'tmp/spacer.png'] do |t|
  head = page_range.first
  head -= 1 if head % 2 == 0
  tail = page_range.last
  tail += 3 - (tail - head) % 4
  book = []
  while head < tail do
    head_page = (head < page_range.first || head > page_range.last) ? 'tmp/blank_page.png' : "build_a5/p#{sprintf('%03d', head)}.png"
    tail_page = tail > page_range.last  ? 'tmp/blank_page.png' : "build_a5/p#{sprintf('%03d', tail)}.png"
    pages     = head % 2 == 0 ? "#{tail_page} tmp/spacer.png #{head_page}" : "#{head_page} tmp/spacer.png #{tail_page}"
    tmp_img   = "tmp/p#{sprintf('%03d_%03d', head, tail)}.png"
    sh "convert +append #{pages} #{tmp_img}.t"
    sh "convert -density 600 -size 7016x4961 xc:blue #{tmp_img}.t -gravity center -composite -rotate #{head % 2 == 0 ? 270 : 90} -threshold 50% #{tmp_img}"
    book << tmp_img
    head += 1
    tail -= 1
  end
  sh <<-_EOS
  convert -page a4 -density 72 -extent 4961x7016 #{book.join ' '} \
  build_a5/book#{sprintf('%03d_%03d', page_range.first, page_range.last)}.pdf
  _EOS
end

file 'tmp/blank_page.png' =>['tmp'] do |t|
  sh <<-_EOS
  convert -size 3390x4724 xc:white #{t.name}
  _EOS
end

file 'tmp/spacer.png' =>['tmp'] do |t|
  sh <<-_EOS
  convert -size 118x4724 xc:white #{t.name}
  _EOS
end

def special_pages
  @special_pages ||= FileList.new('src/page*.png')
end

def special_page_nombres
  @special_page_nombres ||= special_pages.collect {|page| page.match(/\d+/).to_a[0].to_i }
end

def nombre_of(page)
  page.match(/(\d+)\.png$/).to_a[1].to_i
end

def virtual_nombre_of(page)
  nombre = nombre_of page
  nombre - special_page_nombres.count {|n| n < nombre }
end

def episode_number_of(page)
  (virtual_nombre_of(page) - 1) / 4 + 1
end

def right_strip_number_of(page)
  (virtual_nombre_of(page) * 2 - 2) % 8
end

def left_strip_number_of(page)
  right_strip_number_of(page) + 1
end

def t1_name_of(page)
  sprintf(
    'titles/t_%02d_%02d.png',
    episode_number_of(page),
    right_strip_number_of(page),
  )
end

def t2_name_of(page)
  sprintf(
    'titles/t_%02d_%02d.png',
    episode_number_of(page),
    left_strip_number_of(page),
  )
end

def s1_name_of(page)
  sprintf(
    'strips/kaerimichi_%02d_%02d.png',
    episode_number_of(page),
    right_strip_number_of(page),
  )
end

def s2_name_of(page)
  sprintf(
    'strips/kaerimichi_%02d_%02d.png',
    episode_number_of(page),
    left_strip_number_of(page),
  )
end

def nombre_name_of(page)
  sprintf(
    'nombres/n_%03d.png',
    nombre_of(page),
  )
end

def build_name_of(page)
  sprintf(
    'build/p%03d.png',
    nombre_of(page),
  )
end

directory 'src'

file 'src/base.png' =>['src'] do |t|
  sh <<-_EOS
  convert -size 4299x6071 xc:white src/base.png
  _EOS
end

file 'src/titles.txt' =>['src'] do |t|
  sh <<-_EOS
  gshuf -n 400 /usr/share/dict/words > src/titles.txt
  _EOS
end

directory 'titles'

rule(/titles\/.*\.txt$/ => [
  'src/titles.txt',
  'titles',
]) do |t|
  t.name =~ /(\d+)_(\d+)\./
  serial = ($1.to_i - 1) * 8 + $2.to_i + 1
  new_title = `head -#{serial} src/titles.txt | tail -1`
  old_title = File.open(t.name, 'r') {|f| f.read } rescue ''
  File.open(t.name, 'w') {|f| f.puts new_title } if new_title != old_title
end

rule(/titles\/.*\.png$/ => [
  proc {|png| png.sub(/\.png$/, '.txt') },
  'titles',
]) do |t|
  title_txt = File.open(t.source, 'r') {|f| f.read }.strip
  title_txt = ' ' if title_txt =~ /^$/
  sh <<-_EOS
  convert -background none -font './fonts/rounded-mgenplus-1c-medium.ttf' -size 1480x200 -gravity center +antialias caption:'#{title_txt}' #{t.name}
  _EOS
end

directory 'strips'

rule(/strips\/.*\.png$/ => ['strips']) do |t|
  sh <<-_EOS
  convert -size 1880x5464 xc:none #{t.name}
  _EOS
end

directory 'nombres'

rule(/nombres\/.*\.png$/ => ['nombres']) do |t|
  nombre_gravity = nombre_of(t.name) % 2 == 0 ? 'East' : 'West'
  sh <<-_EOS
  convert -background none -font '/Library/Fonts/ヒラギノ丸ゴ ProN W4.otf' -size 3561x80 -gravity #{nombre_gravity} +antialias caption:'#{nombre_of t.name}' #{t.name}
  _EOS
end

directory 'build'

special_pages.each do |src|
  file ('build/p%03d.png' % nombre_of(src)) => [nombre_name_of(src), src] do |t|
    sh <<-_EOS
    convert #{src} \
      -gravity South \
      #{t.name}
    _EOS
  end
end

rule(/^build\/p\d+\.png$/ => [
  proc {|page| t1_name_of page },
  proc {|page| t2_name_of page },
  proc {|page| s1_name_of page },
  proc {|page| s2_name_of page },
  proc {|page| nombre_name_of page },
  'build',
  'src/base.png',
]) do |t|
  composite_right_title = right_strip_number_of(t.name) == 0 ?
    '' :
    "#{t.sources[0]} -geometry +2350+210 -composite"
  sh <<-_EOS
  convert src/base.png \
    #{t.sources[2]} -geometry +2150+311 -composite \
    #{t.sources[3]} -geometry +270+311 -composite \
    #{composite_right_title} \
    #{t.sources[1]} -geometry +470+210 -composite \
    #{t.sources[4]} -gravity South -geometry +3+300 -composite \
    #{t.name}
  _EOS
end

directory "#{ENV['HOME']}/.config/ImageMagick"

file "#{ENV['HOME']}/.config/ImageMagick/thresholds.xml" => ['dither/thresholds.xml', "#{ENV['HOME']}/.config/ImageMagick"] do |t|
  sh <<-_EOS
  mv ~/.config/ImageMagick/thresholds.xml ~/.config/ImageMagick/thresholds.xml~;
  cp -p dither/thresholds.xml ~/.config/ImageMagick/;
  _EOS
end

directory 'tmp/build_a5'

CONVERT_RESIZE = "-gravity Center -resize #{3295 + 118 * 2}x -crop 3390x4724+0+0"
CONVERT_DITHER = '-ordered-dither h85lines'

rule(/^build_a5\/p\d+\.png$/ => [
  proc {|page| build_name_of page },
  'tmp/build_a5',
  "#{ENV['HOME']}/.config/ImageMagick/thresholds.xml",
]) do |t|
  sh <<-_EOS
  convert \
    #{t.sources[0]} -fill white -fuzz 30% +opaque '#010101' -fuzz 0% -opaque '#000000' -morphology Erode Diamond:3 -threshold 50% -negate \
    tmp/#{t.name}.tones_b5_mask.png;
  convert \
    #{t.sources[0]} -fill white -fuzz 0% +opaque '#000000' \
    -compose Lighten \
    tmp/#{t.name}.tones_b5_mask.png -composite \
    -negate \
    tmp/#{t.name}.lines_b5_mask.png;
  convert \
    #{t.sources[0]} \
    -compose Lighten \
    tmp/#{t.name}.lines_b5_mask.png -composite \
    #{CONVERT_RESIZE} \
    #{CONVERT_DITHER} \
    tmp/#{t.name}.tones.png;
  _EOS
  sh <<-_EOS
  convert #{t.sources[0]} -fill white -fuzz 0.5% +opaque '#000000' #{CONVERT_RESIZE} -monochrome -negate tmp/#{t.name}.lines.png;
  _EOS
  sh <<-_EOS
  composite \
    tmp/#{t.name}.tones.png \
    -compose Darken \
    tmp/#{t.name}.lines.png \
    #{t.name};
  _EOS
end

