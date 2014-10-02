require 'mechanize'
require 'icalendar'
require 'optparse'

# define help
def help
  print "Usage: #{$0} [options]...\n\n"
  puts "  -i ID, --id ID, --id=ID\t\t\tSet student ID.(Required)"
  puts "  -p PASSWD, --pass PASSWD, --pass=PASSWD\tSet password.(Required)"
  puts "  -s DATE, --start DATE, --start=DATE\t\tSet date of start.(Option)"
  puts "  -e DATE, --end DATE, --end=DATE\t\tSet date of end.(Option)"
  puts "  -o FILE, --output FILE, --output=FILE\t\tSet filename.(Option)"
  exit
end

# parse and check arguments
begin
  OPTS = {}
  opt = OptionParser.new
  opt.on('-i VAL','--id VAL','--id=VAL') {|id| OPTS[:id] = id}
  opt.on('-p VAL','--pass VAL','--pass=VAL') {|pass| OPTS[:pass] = pass}
  opt.on('-s VAL','--start VAL','--start=VAL') {|time| OPTS[:start] = time}
  opt.on('-e VAL','--end VAL','--end=VAL') {|time| OPTS[:end] = time}
  opt.on('-o VAL','--output VAL','--output=VAL') {|file| OPTS[:output] = file}
  opt.on('-h','--help') {help}
  opt.parse(ARGV)
rescue
  help
end

help if (OPTS[:id].nil? || OPTS[:pass].nil?)
OPTS[:start] = Date.parse(OPTS[:start]) rescue Date.today
OPTS[:end] = (Date.parse(OPTS[:end])+1).to_s.gsub(/-/,'') rescue nil
OPTS[:output] = File.absolute_path(OPTS[:output]) rescue File.absolute_path('ical.ics')

# login
agent = Mechanize.new
agent.follow_meta_refresh = true

page = agent.get('https://com-web.mind.meiji.ac.jp/SSO/sso?url=https%3A%2F%2Foh-o2.meiji.ac.jp%2Fportal%2Finitiatessologin')
next_page = page.form_with(:action => 'icpn200') do |form|
  form.usrid = OPTS[:id]
  form.passwd = OPTS[:pass]
end.submit

# move to classweb
begin
  link_classweb = next_page.links.find {|elem| elem.text.include? "クラスウェブ" }
  classweb = link_classweb.click
rescue
  STDOUT.puts "\x1b[31m"+"Failed to login. Please check arguments."+"\x1b[39m"
  exit
end

# scraping
timetable = {}
week_list = %i[mo tu we th fr sa]
week_list.each {|week_name| timetable[week_name]={}}

tabel_html = classweb.search('.calenderLayout > table[summary=layoutTable]')

week_list.size.times do |week|
  1.upto(7) do |period|
    week_name = week_list[week]
    subject_node = tabel_html.search(".classTitle:nth-of-type(#{period}) td:nth-of-type(#{week+1})")
    infos_node = tabel_html.search(".classDetail:nth-of-type(#{period}) td:nth-of-type(#{week+1})")

    subject = subject_node.text.gsub(/( |\s|\n|\r)/,'')
    infos = infos_node.text.gsub(/( |　|\t)/,'').split.select {|item| !item.empty?}

    timetable[week_name][period] = {
      :subject => !subject.empty? ? subject : nil,
      :lecturer => infos[0],
      :room => infos[1]
    }
  end
end

# make iCal
period_table = {
  1 => {:start => "09:00",:end => "10:30"},
  2 => {:start => "10:40",:end => "12:10"},
  3 => {:start => "13:00",:end => "14:30"},
  4 => {:start => "14:40",:end => "16:10"},
  5 => {:start => "16:20",:end => "17:50"},
  6 => {:start => "18:00",:end => "19:30"},
  7 => {:start => "19:40",:end => "21:10"}
}

cal = Icalendar::Calendar.new

cal.timezone do |t|
  t.tzid = 'Asia/Tokyo'
  t.standard do |s|
    s.tzoffsetfrom = '+0900'
    s.tzoffsetto = '+0900'
    s.dtstart = '19700101T000000'
    s.tzname = 'JST'
  end
end

timetable.each do |week_name, table|
  table.each do |period, infos|
    week = week_list.find_index(week_name)
    date_str = (OPTS[:start]+(week+1-OPTS[:start].wday)%7).to_s

    unless (infos[:subject].nil?)
      cal.event do |e|
        e.dtstart = DateTime.parse("#{date_str} #{period_table[period][:start]}")
        e.dtend = DateTime.parse("#{date_str} #{period_table[period][:end]}")

        e.summary = infos[:subject]
        e.location = infos[:room]
        e.description = infos[:lecturer]
        e.rrule = "FREQ=WEEKLY;BYDAY=#{week_name.to_s.upcase};" + (OPTS[:end].nil? ? "" : "UNTIL=#{OPTS[:end]};")
      end
    end
  end
end

# export
File.open(OPTS[:output], 'w') {|file| file.write cal.to_ical}
puts "Exported #{OPTS[:output]}"
exit