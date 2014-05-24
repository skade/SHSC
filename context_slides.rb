require 'json'
require 'virtus'

module Token
  include Virtus.module

  attribute :tag, String
  attribute :contents, Object

  def method_missing(meth, *args)
    if meth.to_s.end_with?("?")
      return tag == meth.to_s.chomp("?").split('_').map{|e| e.capitalize}.join
    end
    super
  end

  def self.from(h)
    tag = h['t']
    token_class = self.const_get(tag)
    token_class.new(tag: h['t'], contents: h['c'])
  end

  def to_tex
    to_s
  end
end

module Token
  module SimpleSubTokens
    def initialize(h)
      h[:contents] = h[:contents].map{ |t| Token.from(t) }
      super
    end
  end

  class Para
    include Virtus.model
    include Token
    include SimpleSubTokens

    def to_tex
      "\n\n" + contents.map(&:to_tex).join
    end
  end

  class CodeBlock
    include Virtus.model
    include Token

    def initialize(h)
      self.language = h[:contents][0][1][0]
      self.code = h[:contents][1]
    end

    attribute :language, String
    attribute :code, String

    def to_tex
      [
        "\\start#{language.upcase}",
        code,
        "\\stop#{language.upcase}"
      ].join("\n")
    end
  end

  class Header
    include Virtus.model
    include Token

    def initialize(h)
      self.level = h[:contents][0]
      self.ref = h[:contents][1][0]
      h[:contents] = h[:contents][2].map{ |t| Token.from(t) }
      super
    end

    attribute :level, Fixnum
    attribute :ref, String

    def to_tex
      case level
      when 1
        subject = "\\subject"
      else
        subject = "\\subsubject"
      end
      "#{subject}{#{contents.map(&:to_tex).join}}"
    end
  end

  class Str
    include Virtus.model
    include Token

    def to_s
      contents
    end
  end

  class Space
    include Virtus.model
    include Token

    def to_s
      " "
    end
  end

  class Strong
    include Virtus.model
    include Token
    include SimpleSubTokens

    def to_tex
      "{\\bf #{contents.map(&:to_tex).join}}"
    end
  end

  class Emph
    include Virtus.model
    include Token
    include SimpleSubTokens

    def to_tex
      "{\\emphasis #{contents.map(&:to_tex).join}}"
    end
  end

  class HorizontalRule
    include Virtus.model
    include Token
  end

  class BlockQuote
    include Virtus.model
    include Token
    include SimpleSubTokens

    def to_tex
      "{\\italic\\quotation{ #{contents.map(&:to_tex).map(&:strip).join}}}"
    end
  end

  class Plain
    include Virtus.model
    include Token
    include SimpleSubTokens

    def to_tex
      "\\item #{contents.map(&:to_tex).join}"
    end
  end

  class BulletList
    include Virtus.model(constructor: false)
    include Token

    attribute :items, Array[Plain]

    def initialize(h)
      contents = h.delete(:contents)
      self.items = contents.map { |c| Token.from(c[0]) }
    end

    def to_tex
      [
        "\\startitemize",
        self.items.map(&:to_tex).join("\n"),
        "\\stopitemize"
      ].join("\n")
    end
  end

  class RawInline
    include Virtus.model
    include Token

    attribute :type, String
    attribute :raw, String

    def initialize(h)
      self.type = h[:contents][0]
      self.raw = h[:contents][1]
      super
    end

    def to_tex
      raw
    end
  end

  class RawBlock
    include Virtus.model
    include Token

    attribute :raw, String

    def to_tex
      puts self.inspect
    end
  end
end

class Doc
  include Virtus.model(constructor: false)

  def initialize(meta, tokens)
    self.meta = meta
    self.tokens = tokens.map{ |t| Token.from(t) }
  end

  attribute :meta, Hash
  attribute :tokens, Array[Token]
end

class Slide
  include Virtus.model

  attribute :tokens, Array[Token]

  def to_tex
    [
      "\\startstandardmakeup[align=middle]",
      tokens.map(&:to_tex).join("\n"),
      "\\stopstandardmakeup"
    ].join("\n")
  end
end

meta, tokens = JSON.parse($stdin.read)

doc = Doc.new(meta, tokens)

#puts doc.inspect
slides = doc.tokens.each_with_object([]) do |token, slide_list|
  if slide_list.empty?
    if token.horizontal_rule?
      slide_list << Slide.new
      slide_list << Slide.new
    else
      slide = Slide.new
      slide.tokens << token
      slide_list << slide
    end
  elsif token.header?
    slide = Slide.new(:tokens => [token])
    slide_list << slide
  elsif token.horizontal_rule?
    slide_list << Slide.new
  else
    slide_list.last.tokens << token
  end
end

puts <<-HEADER
\\setuppapersize[S6][S6]
\\setuplayout[backspace=10mm,
    width=190mm,
    topspace=5mm,
    header=0mm,
    footer=0mm,
    %height=250mm,
    edge=0mm,
    margin=0mm]
\\setupbackgrounds[page][background=color,backgroundcolor=black]

\\usemodule[vim]
\\usemodule[simplefonts][size=30pt]



\\setmainfont[firasansotnormal]
\\setmonofont[firamonootnormal]
\\setsansfont[firasansotnormal]
%\\definesimplefont[MonoFont][firamonootnormal][size=10pt]
\\definesimplefont[Subject][firasansotnormal][size=90pt]
\\definesimplefont[SubSubject][firasansotnormal][size=50pt]
%\\setmainfont[Tex Gyre Pagella]
%\\setmonofont[Tex Gyre Cursor]
%\\setsansfont[Tex Gyre Heros]
%\\definesimplefont[Subject][TeX Gyre Pagella][size=120pt]
%\\definesimplefont[SubSubject][TeX Gyre Pagella][size=60pt]

%\\definesimplefonttypeface[subject][TeX Gyre Pagella]
%\\definefont[Subject][\\classfont{subject}{serif} at 60pt]
%\\switchtobodyfont[modern,20pt]

\\setuphead [section]    [style=Subject,
                          align=middle]
\\setuphead [subsection] [style=SubSubject,
                          align=middle]

\\definevimtyping [RUBY]  [syntax=ruby,
                           before={\\switchtobodyfont[20pt]},
                           after={\\switchtobodyfont[30pt]},
                           lines=split]
\\definevimtyping [SH]    [syntax=sh,
                           before={\\switchtobodyfont[20pt]},
                           after={\\switchtobodyfont[30pt]}]
\\setuppagenumbering[state=stop]

\\setuptolerance[verytolerant,stretch]

\\setupalign[lohi]
\\setupitemgroup[itemize][align=right]
\\setupinterlinespace[line=1.2\\bodyfontsize]
%\\showboxes
\\definehighlight
  [emphasis]
  [style=italic]


%\\setuplayout[grid=yes]
\\starttext
\\startcolor[white]
HEADER

slides.each do |slide|
  puts slide.to_tex
end

puts <<-FOOTER
\\startcolor[white]
\\stoptext
FOOTER
