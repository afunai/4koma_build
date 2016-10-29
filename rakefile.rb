require 'rake/clean'

CLEAN.include FileList.new('titles/t_*.txt')
CLEAN.include FileList.new('titles/t_*.png')
CLEAN.include FileList.new('nombres/n_*.png')
CLEAN.include FileList.new('tmp/*')
CLOBBER.include FileList.new('build/*')
CLOBBER.include FileList.new('build_a5/*')

def page_range
  head, tail = (ENV['p'] || '1-8').split(/\-/)
  tail ||= head
  (head.to_i .. tail.to_i)
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
  sh "convert -page a5+9+0 -define pdf:page-direction=right-to-left #{files} build_a5/pages_centered_#{range}.pdf"
  sh "convert -page a5 -define pdf:page-direction=right-to-left #{files} build_a5/pages_#{range}.pdf"
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

directory 'tmp/build_a5'

CONVERT_RESIZE = "-gravity South -resize #{3295 + 118 * 2}x -crop #{3295 - 118}x4724+0+130"

rule(/^build_a5\/p\d+\.png$/ => [
  proc {|page| build_name_of page },
  'build_a5',
  'tmp/build_a5',
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
    -ordered-dither h8x8a \
    tmp/#{t.name}.tones.png;

  convert #{t.sources[0]} -fill white -fuzz 1% +opaque '#000000' #{CONVERT_RESIZE} -monochrome -negate tmp/#{t.name}.lines.png;

  composite \
    tmp/#{t.name}.tones.png \
    -compose Darken \
    tmp/#{t.name}.lines.png \
    #{t.name};
  _EOS
end

