require 'mechanize'
require 'icalendar'

term = {:start => '20140922', :end => '20150120'}
hours = {
    1 => {:start => '0900', :end => '1030'},
    2 => {:start => '1040', :end => '1210'},
    3 => {:start => '1300', :end => '1430'},
    4 => {:start => '1440', :end => '1610'},
    5 => {:start => '1620', :end => '1750'},
    6 => {:start => '1800', :end => '1930'},
    7 => {:start => '1940', :end => '2110'},
}
wday = ["SU", "MO", "TU", "WE", "TH", "FR", "SA"]

agent = Mechanize.new
agent.follow_meta_refresh = true

# login
page = agent.get('https://com-web.mind.meiji.ac.jp/SSO/sso?url=https%3A%2F%2Foh-o2.meiji.ac.jp%2Fportal%2Finitiatessologin')
next_page = page.form_with(:action => 'icpn200') do |form|
  form.usrid = ENV['MEIJI_ID']
  form.passwd = ENV['MEIJI_PASS']
end.submit
# move to classweb
link_classweb = next_page.links.find {|elem| elem.text.include? "クラスウェブ" }
classweb = link_classweb.click
raw_table = classweb.search('.calenderLayout > table[summary=layoutTable]')

# scraping
week_table = {}

1.upto(6) do |date|
    week_table[date] = {}
    1.upto(7) do |time|
        name = raw_table.search("//tr[#{time * 2}]/td[#{date}]").text.strip!
        next unless name

        desc = raw_table.search("//tr[#{time * 2 + 1}]/td[#{date}]").text.each_line.to_a.select do |item|
            !item.strip!.empty?
        end

        week_table[date][time] = {
            :name => name,
            :teacher => desc[0],
            :location => desc[1],
            :info => desc[2..-1].join
        }
    end
end

# export
calender = Icalendar::Calendar.new
calender.timezone do |t|
    t.tzid = 'Asia/Tokyo'
    t.standard do |s|
        s.tzoffsetfrom = '+0900'
        s.tzoffsetto = '+0900'
        s.dtstart = '19700101T000000'
        s.tzname = 'JST'
    end
end

week_table.each do |date, time_table|
    time_table.each do |time, clazz|
        calender.event do |e|
            e.dtstart = DateTime.strptime(term[:start] + hours[time][:start], '%Y%m%d%H%M') + date - 1
            e.dtend = DateTime.strptime(term[:start] + hours[time][:end], '%Y%m%d%H%M') + date - 1
            e.summary = clazz[:name]
            # e.organizer = clazz[:teacher]
            e.location = clazz[:location]
            e.description = clazz[:info]
            e.rrule = "FREQ=WEEKLY;UNTIL=#{term[:end]};BYDAY=#{wday[date]}"
        end
    end
end

puts calender.to_ical
