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

directory 'src'

file 'src/paper.png' =>['src'] do |t|
  sh <<-_EOS
  convert -size 4299x6071 xc:white src/paper.png
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
  convert -background none -font '/Library/Fonts/ヒラギノ丸ゴ ProN W4.otf' -size 1480x200 -pointsize 150 -gravity center caption:'#{title_txt}' #{t.name}
  _EOS
end

directory 'strips'

rule(/strips\/.*\.png$/ => ['strips']) do |t|
  sh <<-_EOS
  convert -size 1880x5464 xc:white #{t.name}
  _EOS
end

directory 'nombres'

rule(/nombres\/.*\.png$/ => ['nombres']) do |t|
  sh <<-_EOS
  convert -background none -font '/Library/Fonts/ヒラギノ丸ゴ ProN W4.otf' -size 300x100 -gravity center caption:'#{nombre_of t.name}' #{t.name}
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
    "#{t.sources[0]} -geometry +2339+270 -composite"
  sh <<-_EOS
  convert src/paper.png \
    #{t.sources[2]} -geometry +2139+371 -composite \
    #{t.sources[3]} -geometry +284+371 -composite \
    #{composite_right_title} \
    #{t.sources[1]} -geometry +484+270 -composite \
    #{t.sources[4]} -gravity South -geometry +0+170 -composite \
    #{t.name}
  _EOS
end

