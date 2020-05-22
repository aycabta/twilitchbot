require 'bundler'
require 'sinatra'
require 'slim'
require 'twilio-ruby'

configure do
  set :root, File.dirname(__FILE__)
  set :static, true
  set :public_folder, "#{File.dirname(__FILE__)}/public"
  enable :run
end

get '/' do
  slim :index
end

post '/start' do
  Twilio::TwiML::VoiceResponse.new do |r|
    url = "#{ENV['HEROKU_URL']}/receive_number"
    r.gather timeout: 30, finishOnKey: '#', action: url, method: 'POST' do |g|
      r.say(message: '置き配自動システムへようこそ。追跡番号を入力し、最後に、シャープを押してください。', language: 'ja-jp')
    end
  end.to_xml
end

post '/receive_number' do
  Twilio::TwiML::VoiceResponse.new do |r|
    r.say(message: "入力された番号は、#{params[:Digits].split('').join('、')}、です。", language: 'ja-jp')
  end.to_xml
end
