# Kino.Audio

A kino for rendering a binary audio.

## Examples

    content = File.read!("/path/to/audio.wav")
    Kino.Audio.new(content, :wav)

    content = File.read!("/path/to/audio.wav")
    Kino.Audio.new(content, :wav, autoplay: true, loop: true)

## new/3

Creates a new kino displaying the given binary audio.

The given type can be either `:wav`, `:mp3`/`:mpeg`, `:ogg`
or a string with audio MIME type.

## Options

  * `:autoplay` - whether the audio should start playing as soon as
    it is rendered. Defaults to `false`

  * `:loop` - whether the audio should loop. Defaults to `false`

  * `:muted` - whether the audio should be muted. Defaults to `false`

## play/1

Makes a given kino play the audio.

Play has no effect if the audio is already playing.

## pause/1

Makes a given kino stop playing the audio.