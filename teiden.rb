#!/usr/bin/env ruby -Ku
# -*- coding: utf-8 -*-
require "open-uri"
require "rubygems"
require "json"
require "time"
require "date"

def notifymsg(msg)
  #jsonパーサーを使う
  json = JSON.parser.new(msg)
  #突っ込むためのハッシュ作成
  h = Hash.new
  h = json.parse()

  source = h["source"].to_f
  if source == 1 then
    info = "月間予定"
  elsif source == 2 then
    info = "翌日予定"
  elsif source == 3 then
    info = "当日予定"
  else
    info = "情報なし"
  end
  
  if h["is_implemented"] then
    is_impl =  "実施有り" 
  else
    is_impl = "実施無し"
  end
  
  t = Time.parse(h["date"])
  date = "日付 : " << t.year.to_s << "/" << t.month.to_s << "/" << t.day.to_s << "\n"
  group = "グループ : " << h["group"] << "\n"
  length =  "計画停電対象時間 : "<< h["start"] << "から" << h["end"] << "まで\n"
  bool =  "計画停電の有無 : " << is_impl.to_s << "\n"
  rank = "グループ内停電順位 : " << h["order"].to_s << "\n"
  infosource =  "情報源 : " << info << "\n"
  notify_source = date << group << bool << length << rank << infosource
  return notify_source
end

Plugin.create :teiden_kansai do
  src = ''
  group = (UserConfig[:teiden_area]|| []).select{|m|!m.empty?}
  sleeptime = (UserConfig[:retrive_interval_api_access].to_i || 1*60 ).to_i * 60
  today = Date.today
  weekday = today.wday
  if group then
    Thread.new {
      while true
        if  (weekday.to_i == 0 || weekday.to_i == 6 ) then
          bg_system("notify-send","notice!","通知が有効なのは平日だけです")
        else
          begin
            open("http://kteiden.chibiegg.net/api/kteiden.json?&group=#{group[0]}"){|file|
              src = file.read.gsub(/^\[/,"").gsub(/\]$/,"") #前後についている[]を取り払う
            }
            notify_source = notifymsg(src)
            
            bg_system("notify-send","関西停電情報",
                      "#{notify_source}")
          rescue JSON::ParserError
            print "json parse error."
            bg_system("notify-send","notice!", 
                      "有効なエリア情報がありません。\n設定をして再起動してください")
          rescue OpenURI::HTTPError
            print "Http bad request."
            bg_system("notify-send","notice!", 
                      "APIへの接続が確立できませんでした。")
          end
        end
          sleep sleeptime
      end
    }
  else
    bg_system("notify-send","notice!", 
              "通知を有効にするには停電情報タブの設定をして再起動してください")
  end

  settings "関西電力停電情報" do
    settings "エリア情報(ex.4-F etc.)と通知間隔(単位：分)を入力してください" do
      multi "エリア(一番上の設定が有効)", :teiden_area
      adjustment('通知間隔(分)', :retrive_interval_api_access, 1, 24*60)
    end
  end

end
