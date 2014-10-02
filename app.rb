require 'mechanize'
require 'icalendar'

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
p classweb.search('.calenderLayout > table[summary=layoutTable]')
