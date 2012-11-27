#!/usr/bin/env lua

require 'Test.More'
plan 'no_plan'
require_ok('layla.tokenizer.words')
words = require 'layla.tokenizer.words':new()

local test_cases = {
  {
    ' " why hello there. «yes». "foo is a bar", e.g. bla ... yes',
    {'"', 'why', 'hello', 'there', '.', '«', 'yes', '».', '"', 'foo', 'is', 'a', 'bar', '",', 'e.g.', 'bla', '...', 'yes'},
    '" Why hello there. «Yes». "Foo is a bar", e.g. bla ... yes.',
  },
  {
    "someone: how're you?",
    {'someone', ':', "how're", 'you', '?'},
    "Someone: How're you?",
  },
  {
    'what?! well...',
    {'what', '?!', 'well', '...'},
    'What?! Well...',
  },
  {
    'hello. you: what are you doing?',
    {'hello', '.', 'you', ':', 'what', 'are', 'you', 'doing', '?'},
    'Hello. You: What are you doing?',
  },
  {
    'foo: foo: foo: what are you doing?',
    {'foo', ':', 'foo', ':', 'foo', ':', 'what', 'are', 'you', 'doing', '?'},
    'Foo: Foo: Foo: What are you doing?',
  },
  {
    "I'm talking about this key:value thing",
    {"i'm", 'talking', 'about', 'this', 'key', ':', 'value', 'thing'},
    "I'm talking about this key:value thing.",
  },
  {
    "what? but that's impossible",
    {'what', '?', 'but', "that's", 'impossible'},
    "What? But that's impossible.",
  },
  {
    'on example.com? yes',
    {'on', 'example.com', '?', 'yes'},
    "On example.com? Yes.",
  },
  {
    'pi is 3.14, well, almost',
    {'pi', 'is', '3.14', ',', 'well', ',', 'almost'},
    "Pi is 3.14, well, almost.",
  },
  {
    'foo 0.40 bar or .40 bar bla 0,40 foo ,40',
    {'foo', '0.40', 'bar', 'or', '.40', 'bar', 'bla', '0,40', 'foo', ',40'},
    'Foo 0.40 bar or .40 bar bla 0,40 foo ,40.',
  },
  {
    "sá ''karlkyns'' aðili í [[hjónaband]]i tveggja lesbía?",
    {'sá', "''", 'karlkyns', "''", 'aðili', 'í', '[[', 'hjónaband', ']]', 'i', 'tveggja', 'lesbía', '?'},
    "Sá ''karlkyns'' aðili í [[hjónaband]]i tveggja lesbía?",
  },
  {
    "you mean i've got 3,14? yes",
    {'you', 'mean', "i've", 'got', '3,14', '?', 'yes'},
    "You mean I've got 3,14? Yes.",
  },
  {
    'Pretty girl like her "peak". oh and you’re touching yourself',
    {'pretty', 'girl', 'like', 'her', '"', 'peak', '".', 'oh', 'and', "you’re", 'touching', 'yourself'},
    'Pretty girl like her "peak". Oh and you’re touching yourself.',
  },
  {
    'http://foo.BAR/bAz',
    {'http://foo.BAR/bAz'},
    'http://foo.BAR/bAz',
  },
  {
    'http://www.example.com/some/path?funny**!(),,:;@=&=',
    {'http://www.example.com/some/path?funny**!', '(),,:;@=&='},
    'http://www.example.com/some/path?funny**!(),,:;@=&=',
  },
  {
    'svn+ssh://svn.wikimedia.org/svnroot/mediawiki',
    {'svn+ssh://svn.wikimedia.org/svnroot/mediawiki'},
    'svn+ssh://svn.wikimedia.org/svnroot/mediawiki',
  },
  {
    "foo bar baz. i said i'll do this",
    {'foo', 'bar', 'baz', '.', 'i', 'said', "i'll", 'do', 'this'},
    "Foo bar baz. I said I'll do this.",
  },
  {
    'talking about i&34324 yes',
    {'talking', 'about', 'i', '&', '34324', 'yes'},
    'Talking about i&34324 yes.',
  },
  {
    'talking about i',
    {'talking', 'about', 'i'},
    'Talking about i.',
  },
  {
    'none, as most animals do, I love conservapedia.',
    {'none', ',', 'as', 'most', 'animals', 'do', ',', 'I', 'love', 'conservapedia', '.'},
    'None, as most animals do, I love conservapedia.',
  },
  {
    'hm...',
    {'hm', '...'},
    'Hm...',
  },
  {
    'anti-scientology demonstration in london? hella-cool',
    {'anti-scientology', 'demonstration', 'in', 'london', '?', 'hella-cool'},
    'Anti-scientology demonstration in london? Hella-cool.',
  },
  {
    'This. compound-words are cool',
    {'this', '.', 'compound-words', 'are', 'cool'},
    'This. Compound-words are cool.',
  },
  {
    'Foo. Compound-word',
    {'foo', '.', 'compound-word'},
    'Foo. Compound-word.',
  },
  {
    'one',
    {'one'},
    'One.'
  },
  {
    'cpanm is a true "religion"',
    {'cpanm', 'is', 'a', 'true', '"', 'religion', '"'},
    'Cpanm is a true "religion."',
  },
  {
    'cpanm is a true "anti-religion"',
    {'cpanm', 'is', 'a', 'true', '"', 'anti-religion', '"'},
    'Cpanm is a true "anti-religion."'
  },
  {
    'Maps to weekends/holidays',
    {'maps', 'to', 'weekends', '/', 'holidays'},
    'Maps to weekends/holidays.'
  },
  {
    's/foo/bar',
    {'s', '/', 'foo', '/', 'bar'},
    's/foo/bar',
  },
  {
    's/foo/bar/',
    {'s', '/', 'foo', '/', 'bar', '/'},
    's/foo/bar/',
  },
  {
    'Where did I go? http://foo.bar/',
    {'where', 'did', 'I', 'go', '?', 'http://foo.bar/'},
    'Where did I go? http://foo.bar/',
  },
  {
    'What did I do? s/foo/bar/',
    {'what', 'did', 'I', 'do', '?', 's', '/', 'foo', '/', 'bar', '/'},
    'What did I do? s/foo/bar/',
  },
  {
    'I called foo() and foo(bar)',
    {'I', 'called', 'foo', '()', 'and', 'foo', '(', 'bar', ')'},
    'I called foo() and foo(bar)',
  },
  {
     'foo() is a function',
     {'foo', '()', 'is', 'a', 'function'},
     'foo() is a function.',
  },
  {
    'the symbol : and the symbol /',
    {'the', 'symbol', ':', 'and', 'the', 'symbol', '/'},
    'The symbol : and the symbol /',
  },
  {
    '.com bubble',
    {'.com', 'bubble'},
    '.com bubble.',
  },
  {
    'við vorum þar. í norður- eða vesturhlutanum',
    {'við', 'vorum', 'þar', '.', 'í', 'norður-', 'eða', 'vesturhlutanum'},
    'Við vorum þar. Í norður- eða vesturhlutanum.',
  },
  {
    "i'm talking about -postfix. yeah",
    {"i'm", 'talking', 'about', '-', 'postfix', '.', 'yeah'},
    "I'm talking about -postfix. yeah.",
  },
  {
    "But..what about me? but...no",
    {'but', '..', 'what', 'about', 'me', '?', 'but', '...', 'no'},
    "But..what about me? But...no.",
  },
  {
    "For foo'345 'foo' bar",
    {'for', 'foo', "'", '345', "'", 'foo', "'", 'bar'},
    "For foo'345 'foo' bar.",
  },
  {
    'loves2spooge',
    {'loves2spooge'},
    'Loves2spooge.',
  },
  {
    'she´ll be doing it now',
    {'she´ll', 'be', 'doing', 'it', 'now'},
    'She´ll be doing it now.',
  },
  {
    'CPAN upload: Crypt-Rijndael-MySQL-0.02 by SATOH',
    {'CPAN', 'upload', ':', 'Crypt-Rijndael-MySQL-0.02', 'by', 'SATOH'},
    'CPAN upload: Crypt-Rijndael-MySQL-0.02 by SATOH.',
  },
  {
    "I use a resolution of 800x600 on my computer",
    {'I', 'use', 'a', 'resolution', 'of', '800x600', 'on', 'my', 'computer'},
    "I use a resolution of 800x600 on my computer.",
  },
  {
    'WOAH 3D',
    {'WOAH', '3D'},
    'WOAH 3D.',
  },
  {
    "jarl sounds like yankee negro-lovers. britain was even into old men.",
    {'jarl', 'sounds', 'like', 'yankee', 'negro-lovers', '.', 'britain', 'was', 'even', 'into', 'old', 'men', '.'},
    "Jarl sounds like yankee negro-lovers. Britain was even into old men.",
  },
  {
    "just look at http://beint.lýðræði.is does it turn tumi metrosexual",
    {'just', 'look', 'at', 'http://beint.lýðræði.is', 'does', 'it', 'turn', 'tumi', 'metrosexual'},
    "Just look at http://beint.lýðræði.is does it turn tumi metrosexual.",
  },
  {
     'du: Invalid option --^',
     {'du', ':', 'invalid', 'option', '--^'},
     'Du: Invalid option --^',
  },
  {
    '4.1GB downloaded, 95GB uploaded',
    {'4.1GB', 'downloaded', ',', '95GB', 'uploaded'},
    '4.1GB downloaded, 95GB uploaded.',
  },
  {
    'Use <http://google.com> as your homepage',
    {'use', '<', 'http://google.com', '>', 'as', 'your', 'homepage'},
    'Use <http://google.com> as your homepage.',
  },
  {
    'Foo http://æðislegt.is,>>> bar',
    {'foo', 'http://æðislegt.is', ',>>>', 'bar'},
    'Foo http://æðislegt.is,>>> bar.',
  },
  {
    'Foo http://æðislegt.is,$ bar',
    {'foo', 'http://æðislegt.is', ',$', 'bar'},
    'Foo http://æðislegt.is,$ bar.',
  },
  {
    'http://google.is/search?q="stiklað+á+stóru"',
    {'http://google.is/search?q="stiklað+á+stóru"'},
    'http://google.is/search?q="stiklað+á+stóru"',
  },
  --{
  --  'this is STARGΛ̊TE',
  --  {'this', 'is', 'STARGΛ̊TE'},
  --  'This is STARGΛ̊TE.',
  --},
  {
    'tumi.st@gmail.com tumi.st@gmail.com tumi.st@gmail.com',
    {'tumi.st@gmail.com', 'tumi.st@gmail.com', 'tumi.st@gmail.com'},
    'tumi.st@gmail.com tumi.st@gmail.com tumi.st@gmail.com',
  },
  {
    'tumi@foo',
    {'tumi@foo'},
    'tumi@foo',
  },
  {
    'tumi@foo.co.uk',
    {'tumi@foo.co.uk'},
    'tumi@foo.co.uk',
  },
  {
    'e.g. the river',
    {'e.g.', 'the', 'river'},
    'E.g. the river.',
  },
  {
    'dong–licking is a really valuable book.',
    {'dong–licking', 'is', 'a', 'really', 'valuable', 'book', '.'},
    'Dong–licking is a really valuable book.',
  },
  {
    'taka úr sources.list',
    {'taka', 'úr', 'sources.list'},
    'Taka úr sources.list',
  },
  {
    'Huh? what? i mean what is your wife a...goer...eh? know what a dude last night...',
    {'huh', '?', 'what', '?', 'i', 'mean', 'what', 'is', 'your', 'wife', 'a', '...', 'goer', '...', 'eh', '?', 'know', 'what', 'a', 'dude', 'last', 'night', '...'},
    'Huh? What? I mean what is your wife a...goer...eh? Know what a dude last night...',
  },
  {
    'neeeigh!',
    {'neeeigh', '!'},
    'Neeeigh!',
  },
  {
    'neeeigh.',
    {'neeeigh', '.'},
    'Neeeigh.',
  },
  {
    'odin-: foo-- # blah. odin-: yes',
    {'odin-', ':', 'foo', '--', '#', 'blah', '.', 'odin-', ':', 'yes'},
    'Odin-: Foo-- # blah. Odin-: Yes.',
  },
  {
    "struttin' that nigga",
    {"struttin'", 'that', 'nigga'},
    "Struttin' that nigga.",
  },
  {
    '"maybe" and A better deal. "would" still need my coffee with tea.',
    {'"', 'maybe', '"', 'and', 'A', 'better', 'deal', '.', '"', 'would', '"', 'still', 'need', 'my', 'coffee', 'with', 'tea', '.'},
    '"Maybe" and A better deal. "Would" still need my coffee with tea.',
  },
  {
    "This Acme::POE::Tree module is neat. Acme::POE::Tree",
    {'this', 'Acme::POE::Tree', 'module', 'is', 'neat', '.', 'Acme::POE::Tree'},
    "This Acme::POE::Tree module is neat. Acme::POE::Tree",
  },
  {
    "I use POE-Component-IRC",
    {'I', 'use', 'POE-Component-IRC'},
    "I use POE-Component-IRC.",
  },
  {
    "You know, 4-3 equals 1",
    {'you', 'know', ',', '4-3', 'equals', '1'},
    "You know, 4-3 equals 1.",
  },
  {
    "moo-5 moo-5-moo moo_5",
    {'moo-5', 'moo-5-moo', 'moo_5'},
    "Moo-5 moo-5-moo moo_5.",
  },
  {
    "::Class Class:: ::Foo::Bar Foo::Bar:: Foo::Bar",
    {'::Class', 'Class::', '::Foo::Bar', 'Foo::Bar::', 'Foo::Bar'},
    "::Class Class:: ::Foo::Bar Foo::Bar:: Foo::Bar",
  },
  {
    "It's as simple as C-u C-c C-t C-t t",
    {"it's", 'as', 'simple', 'as', 'C-u', 'C-c', 'C-t', 'C-t', 't'},
    "It's as simple as C-u C-c C-t C-t t.",
  },
  {
    "foo----------",
    {"foo", "----------"},
    "foo----------",
  },
  {
    "HE'S A NIGGER! HE'S A... wait",
    {"HE'S", 'A', 'NIGGER', '!', "HE'S", 'A', '...', 'wait'},
    "HE'S A NIGGER! HE'S A... wait.",
  },
  {
    "I use\nPOE-Component-IRC",
    {'I', 'use', 'POE-Component-IRC'},
    "I use POE-Component-IRC.",
  },
  {
    "I use POE-Component- \n IRC",
    {'I', 'use', 'POE-Component-IRC'},
    "I use POE-Component-IRC.",
  },
  {
    "I wrote theres_no_place_like_home.ly. And then some.",
    {'I', 'wrote', 'theres_no_place_like_home.ly', '.', 'and', 'then', 'some', '.'},
    "I wrote theres_no_place_like_home.ly. And then some.",
  },
  {
    "The file is /hlagh/bar/foo.txt. Just read it.",
    {'the', 'file', 'is', '/hlagh/bar/foo.txt', '.', 'just', 'read', 'it', '.'},
    "The file is /hlagh/bar/foo.txt. Just read it.",
  },
  {
    "The file is C:\\hlagh\\bar\\foo.txt. Just read it.",
    {'the', 'file', 'is', 'C:\\hlagh\\bar\\foo.txt', '.', 'just', 'read', 'it', '.'},
    "The file is C:\\hlagh\\bar\\foo.txt. Just read it.",
  },
  {
    "2011-05-05 22:55 22:55Z 2011-05-05T22:55Z 2011-W18-4 2011-125 12:00±05:00 22:55 PM",
    {'2011-05-05', '22:55', '22:55Z', '2011-05-05T22:55Z', '2011-W18-4', '2011-125', '12:00±05:00', '22:55 PM'},
    "2011-05-05 22:55 22:55Z 2011-05-05T22:55Z 2011-W18-4 2011-125 12:00±05:00 22:55 PM.",
  },
  {
    '<@literal> oh hi < literal> what is going on?',
    {'<@literal>', 'oh', 'hi', '< literal>', 'what', 'is', 'going', 'on', '?'},
    '<@literal> oh hi < literal> what is going on?',
  },
  {
    'It costs $.50, no, wait, it cost $2.50... or 50¢',
    {'it', 'costs', '$.50', ',', 'no', ',', 'wait', ',', 'it', 'cost', '$2.50', '...', 'or', '50¢'},
    'It costs $.50, no, wait, it cost $2.50... or 50¢.',
  },
  {
    '10pt or 12em or 15cm',
    {'10pt', 'or', '12em', 'or', '15cm'},
    '10pt or 12em or 15cm.',
  },
  {
    'failo is #1',
    {'failo', 'is', '#1'},
    'Failo is #1',
  },
  {
    'We are in #perl',
    {'we', 'are', 'in', '#perl'},
    'We are in #perl.'
  },
  {
    '</foo>',
    {'</foo>'},
    '</foo>',
  },
  {
    'ATMs in Baltimore',
    {'ATMs', 'in', 'baltimore'},
    'ATMs in baltimore',
  },
  {
    "I’m here",
    {"i’m", "here"},
    "I’m here.",
  },
  {
    "I´m here",
    {"i´m", "here"},
    "I´m here.",
  },
  {
    'I was shopping at B&H',
    {'I', 'was', 'shopping', 'at', 'B&H'},
    'I was shopping at B&H.',
  },
  {
    "it's here: file://foo/bar/baz.txt",
    {"it's", 'here', ':', 'file://foo/bar/baz.txt'},
    "It's here: file://foo/bar/baz.txt",
  },
  {
    "þetta, hitt, o.s.frv. og t.d.",
    {"þetta", ",", "hitt", ",", "o.s.frv.", "og", "t.d."},
    "Þetta, hitt, o.s.frv. og t.d.",
  },
  {
    "http://www.youtube.com/watch?v=1Z2iBG9lG_s#t=3m20s",
    {"http://www.youtube.com/watch?v=1Z2iBG9lG_s#t=3m20s"},
    "http://www.youtube.com/watch?v=1Z2iBG9lG_s#t=3m20s",
  },
}

for i, test in ipairs(test_cases) do
  local before = os.clock()
  local tokens = words:make_tokens(test[1])
  local after = os.clock()
  cmp_ok(after - before, '<', 1, 'Tokenizing in <1 second')

  local t = {}
  for i, token_spec in next,tokens,nil do
    t[i] = token_spec[2]
  end
  is_deeply(t, test[2], "Tokens are correct for: "..test[1])
  --print("before: "..before.."\tafter: "..after)

  before = os.clock()
  local output = words:make_output(tokens)
  after = os.clock()
  cmp_ok(after - before, '<', 1, 'Making output in <1 second')
  --is(output, test[3], "Output is correct")
end

done_testing()

-- vim: ft=lua
