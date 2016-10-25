task default: :all

task :all, [:last_page] do |t, args|
  args.with_defaults(:last_page => 1)
  args.last_page.to_i.times do |i|
    Rake::Task['build/p%03d.png' % (i + 1)].invoke
  end
end

def nombre_of(page)
  page.match(/(\d+)\.png$/).to_a[1].to_i
end

def episode_number_of(page)
  (nombre_of(page) - 1) / 4 + 1
end

def right_strip_number_of(page)
  (nombre_of(page) * 2 - 2) % 8
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
    'strips/k_%02d_%02d.png',
    episode_number_of(page),
    right_strip_number_of(page),
  )
end

def s2_name_of(page)
  sprintf(
    'strips/k_%02d_%02d.png',
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

directory 'src'

file 'src/paper.png' =>['src'] do |t|
  sh <<-_EOS
  convert -size 480x640 xc:white -fill none -stroke blue -strokewidth 1 -draw "rectangle 10,10 470,630" src/paper.png
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
  sh <<-_EOS
  head -#{serial} src/titles.txt | tail -1 > #{t.name}
  _EOS
end

rule(/titles\/.*\.png$/ => [
  proc {|png| png.sub(/\.png$/, '.txt') },
  'titles',
]) do |t|
  title_txt = File.open(t.source, 'r') {|f| f.read }.strip
  sh <<-_EOS
  convert -background white -font '/Library/Fonts/ヒラギノ丸ゴ ProN W4.otf' -size 180x20 -gravity center caption:'#{title_txt}' #{t.name}
  _EOS
end

directory 'strips'

rule(/strips\/.*\.png$/ => ['strips']) do |t|
  sh <<-_EOS
  convert -size 2x5 xc: +noise Random -scale 10000% #{t.name}
  _EOS
end

directory 'nombres'

rule(/nombres\/.*\.png$/ => ['nombres']) do |t|
  sh <<-_EOS
  convert -background white -font '/Library/Fonts/ヒラギノ丸ゴ ProN W4.otf' -size 100x15 -gravity center caption:'#{nombre_of t.name}' #{t.name}
  _EOS
end

directory 'build'

rule(/^build\/p\d+\.png$/ => [
  proc {|page| t1_name_of page },
  proc {|page| t2_name_of page },
  proc {|page| s1_name_of page },
  proc {|page| s2_name_of page },
  proc {|page| nombre_name_of page },
  'build',
  'src/paper.png',
]) do |t|
  composite_right_title = right_strip_number_of(t.name) == 0 ?
    '' :
    "#{t.sources[0]} -geometry +260+30 -composite"
  sh <<-_EOS
  convert src/paper.png \
    #{composite_right_title} \
    #{t.sources[1]} -geometry +40+30 -composite \
    #{t.sources[2]} -geometry +250+60 -composite \
    #{t.sources[3]} -geometry +30+60 -composite \
    #{t.sources[4]} -gravity South -geometry +0+40 -composite \
    #{t.name}
  _EOS
end

