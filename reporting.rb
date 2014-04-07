require 'rubygems'

env = (ENV["RACK_ENV"] || ENV["RAILS_ENV"] || "development").to_sym

# Set up gems listed in the Gemfile.
gemfile = File.expand_path('../Gemfile', __FILE__)
begin
  ENV['BUNDLE_GEMFILE'] = gemfile
  require 'bundler'
  Bundler.setup
rescue Bundler::GemNotFound => e
  STDERR.puts e.message
  STDERR.puts "Try running `bundle install`."
  exit!
end if File.exist?(gemfile)

# If you have a Gemfile, require the gems listed there, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(:default, env) if defined?(Bundler)

require 'active_support'
require 'active_support/core_ext/object/conversions'
require 'icalendar'

def time_format(seconds)
  minutes = seconds / 60
  hours = (minutes / 60)
  minutes = minutes % 60
  "#{hours}h#{minutes > 0 ? minutes : ''}"
end

cal_file = File.open(Dir[File.expand_path('../*.ics', __FILE__)].first)
cals = Icalendar.parse(cal_file)
cal = cals.first

start_min, start_max = [Time.now.beginning_of_week.utc, Time.now.end_of_week.utc]

durations = {}
cal.events.each do |event|
  if event.dtstart > start_min && event.dtend < start_max && event.transp == 'OPAQUE'
    duration = event.dtend.to_i - event.dtstart.to_i
    key = event.summary.slugify_trim
    durations[key] ||= {:title => event.summary, :duration => 0}
    durations[key][:duration] += duration
  end
end

durations = durations.collect { |a, b| [a, b] }.sort { |a, b| a[0] <=> b[0] }
durations = ActiveSupport::OrderedHash[durations]

content = ActiveSupport::OrderedHash.new
durations.collect do |dc_title, infos|
  duration = time_format(infos[:duration])
  title = infos[:title].downcase.to_s.gsub(/(\A| )./) { |m| m.upcase }
  content[title] = duration
end

max_length = content.keys.map { |t| t.length }.max
content.each do |title, duration|
  puts "#{title.ljust(max_length, ' ')}   #{duration}"
end

duration = durations.collect { |key, infos| infos[:duration] }.reduce(0) do |a, e|
  a += e
  a
end
puts "Total des heures : #{time_format duration}"