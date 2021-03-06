module Searchable
  module Area
    extend ActiveSupport::Concern

    included do
      include Elasticsearch::Model

      # a. サジェスト用のindex
      index_name "area_#{Rails.env}"
      document_type "area"

      # b. self.analyzer_settingsで下のほうに定義したanalyzerを使えるようにする。
      settings analysis: self.analyzer_settings do
        mapping _source: { enabled: true }, _all: { enabled: false } do
          indexes :id, type: 'integer'
          indexes :name, index: true, type: 'text', fielddata: true, fields: {
            autocomplete: {
              type: "text",
              search_analyzer: "autocomplete_search_analyzer",
              analyzer: "autocomplete_index_analyzer"
            },
            readingform: {
              type: "text",
              search_analyzer: "readingform_search_analyzer",
              analyzer: 'readingform_index_analyzer'
            },
            raw: {
              type: "keyword",
              index: true
            }
          }
        end
      end

      def as_indexed_json(*)
        attributes
          .symbolize_keys
          .slice(:id, :name)
          .merge(type: "area")
          .merge(
            created_at: created_at.strftime("%Y-%m-%d %H:%M:%S")
          )
      end
    end

    class_methods do
      def create_index!
        client = __elasticsearch__.client
        client.indices.delete index: self.index_name rescue nil

        client.indices.create(
          index: self.index_name,
          body: {
            settings: self.settings.to_hash,
            mappings: self.mappings.to_hash
          }
        )
      end

      # d. 検索クエリの定義
      def search(query)
        __elasticsearch__.search({
          size: 0,
          query: {
            bool: {
              should: [{
                match: {
                  "name.autocomplete" => {
                    query: query
                  }
                }
              }, {
                match: {
                  "name.readingform" => {
                    query: query,
                    fuzziness: "AUTO",
                    operator: "and"
                  }
                }
              }]
            }
          },
          aggs: {
            keywords: {
              terms: {
                field: "name",
                order: {
                  _count: "desc"
                },
                # size: "5"
              }
            }
          }
        })
      end

      def analyzer_settings
        {
          analyzer: {
            keyword_analyzer: {
              type: "custom",
              char_filter: ["normalize", "whitespaces"],
              tokenizer: "keyword",
              filter: ["lowercase", "trim", "maxlength"]
            },
            autocomplete_index_analyzer: {
              type: "custom",
              char_filter: ["normalize", "whitespaces"],
              tokenizer: "keyword",
              filter: ["lowercase", "trim", "maxlength", "engram"]
            },
            autocomplete_search_analyzer: {
              type: "custom",
              char_filter: ["normalize", "whitespaces"],
              tokenizer: "keyword",
              filter: ["lowercase", "trim", "maxlength"]
            },
            readingform_index_analyzer: {
              type: "custom",
              char_filter: ["normalize", "whitespaces"],
              tokenizer: "japanese_normal",
              filter: ["lowercase", "trim", "readingform", "asciifolding", "maxlength", "engram"]
            },
            readingform_search_analyzer:  {
              type: "custom",
              char_filter: ["normalize", "whitespaces", "katakana", "romaji"],
              tokenizer: "japanese_normal",
              filter: ["lowercase", "trim", "maxlength", "readingform", "asciifolding"]
            },
          },
          filter: {
            readingform: {
              type: "kuromoji_readingform",
              use_romaji: true
            },
            engram: {
              type: "edgeNGram",
              min_gram: 1,
              max_gram: 36
            },
            maxlength: {
              type: "length",
              max: 36
            },
            pos_filter: {
              type: 'kuromoji_part_of_speech',
              stoptags: ['助詞-格助詞-一般', '助詞-終助詞'],
            },
          },
          char_filter: {
            normalize: {
              type: "icu_normalizer",
              name: "nfkc_cf",
              mode: "compose",
            },
            katakana: {
              type: "mapping",
              mappings: [
                "ぁ=>ァ", "ぃ=>ィ", "ぅ=>ゥ", "ぇ=>ェ", "ぉ=>ォ",
                "っ=>ッ", "ゃ=>ャ", "ゅ=>ュ", "ょ=>ョ",
                "が=>ガ", "ぎ=>ギ", "ぐ=>グ", "げ=>ゲ", "ご=>ゴ",
                "ざ=>ザ", "じ=>ジ", "ず=>ズ", "ぜ=>ゼ", "ぞ=>ゾ",
                "だ=>ダ", "ぢ=>ヂ", "づ=>ヅ", "で=>デ", "ど=>ド",
                "ば=>バ", "び=>ビ", "ぶ=>ブ", "べ=>ベ", "ぼ=>ボ",
                "ぱ=>パ", "ぴ=>ピ", "ぷ=>プ", "ぺ=>ペ", "ぽ=>ポ",
                "ゔ=>ヴ",
                "あ=>ア", "い=>イ", "う=>ウ", "え=>エ", "お=>オ",
                "か=>カ", "き=>キ", "く=>ク", "け=>ケ", "こ=>コ",
                "さ=>サ", "し=>シ", "す=>ス", "せ=>セ", "そ=>ソ",
                "た=>タ", "ち=>チ", "つ=>ツ", "て=>テ", "と=>ト",
                "な=>ナ", "に=>ニ", "ぬ=>ヌ", "ね=>ネ", "の=>ノ",
                "は=>ハ", "ひ=>ヒ", "ふ=>フ", "へ=>ヘ", "ほ=>ホ",
                "ま=>マ", "み=>ミ", "む=>ム", "め=>メ", "も=>モ",
                "や=>ヤ", "ゆ=>ユ", "よ=>ヨ",
                "ら=>ラ", "り=>リ", "る=>ル", "れ=>レ", "ろ=>ロ",
                "わ=>ワ", "を=>ヲ", "ん=>ン"
              ]
            },
            romaji: {
              type: "mapping",
              mappings: [
                "キャ=>kya", "キュ=>kyu", "キョ=>kyo",
                "シャ=>sha", "シュ=>shu", "ショ=>sho",
                "チャ=>cha", "チュ=>chu", "チョ=>cho",
                "ニャ=>nya", "ニュ=>nyu", "ニョ=>nyo",
                "ヒャ=>hya", "ヒュ=>hyu", "ヒョ=>hyo",
                "ミャ=>mya", "ミュ=>myu", "ミョ=>myo",
                "リャ=>rya", "リュ=>ryu", "リョ=>ryo",
                "ファ=>fa", "フィ=>fi", "フェ=>fe", "フォ=>fo",
                "ギャ=>gya", "ギュ=>gyu", "ギョ=>gyo",
                "ジャ=>ja", "ジュ=>ju", "ジョ=>jo",
                "ヂャ=>ja", "ヂュ=>ju", "ヂョ=>jo",
                "ビャ=>bya", "ビュ=>byu", "ビョ=>byo",
                "ヴァ=>va", "ヴィ=>vi", "ヴ=>v", "ヴェ=>ve", "ヴォ=>vo",
                "ァ=>a", "ィ=>i", "ゥ=>u", "ェ=>e", "ォ=>o",
                "ッ=>t",
                "ャ=>ya", "ュ=>yu", "ョ=>yo",
                "ガ=>ga", "ギ=>gi", "グ=>gu", "ゲ=>ge", "ゴ=>go",
                "ザ=>za", "ジ=>ji", "ズ=>zu", "ゼ=>ze", "ゾ=>zo",
                "ダ=>da", "ヂ=>ji", "ヅ=>zu", "デ=>de", "ド=>do",
                "バ=>ba", "ビ=>bi", "ブ=>bu", "ベ=>be", "ボ=>bo",
                "パ=>pa", "ピ=>pi", "プ=>pu", "ペ=>pe", "ポ=>po",
                "ア=>a", "イ=>i", "ウ=>u", "エ=>e", "オ=>o",
                "カ=>ka", "キ=>ki", "ク=>ku", "ケ=>ke", "コ=>ko",
                "サ=>sa", "シ=>shi", "ス=>su", "セ=>se", "ソ=>so",
                "タ=>ta", "チ=>chi", "ツ=>tsu", "テ=>te", "ト=>to",
                "ナ=>na", "ニ=>ni", "ヌ=>nu", "ネ=>ne", "ノ=>no",
                "ハ=>ha", "ヒ=>hi", "フ=>fu", "ヘ=>he", "ホ=>ho",
                "マ=>ma", "ミ=>mi", "ム=>mu", "メ=>me", "モ=>mo",
                "ヤ=>ya", "ユ=>yu", "ヨ=>yo",
                "ラ=>ra", "リ=>ri", "ル=>ru", "レ=>re", "ロ=>ro",
                "ワ=>wa", "ヲ=>o", "ン=>n"
              ]
            },
            whitespaces: {
              type: "pattern_replace",
              pattern: "\\s{2,}",
              replacement: "\u0020"
            },
          },
          tokenizer: {
            japanese_normal: {
              mode: "normal",
              type: "kuromoji_tokenizer"
            },
            engram: {
              type: "edgeNGram",
              min_gram: 1,
              max_gram: 36
            }
          },
        }
      end
    end
  end
end