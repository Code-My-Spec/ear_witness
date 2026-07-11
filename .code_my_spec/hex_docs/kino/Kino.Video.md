# Kino.Video

A kino for rendering a binary video.

## Examples

    content = File.read!("/path/to/video.mp4")
    Kino.Video.new(content, :mp4)

    content = File.read!("/path/to/video.mp4")
    Kino.Video.new(content, :mp4, autoplay: true, loop: true)

## new/3

Creates a new kino displaying the given binary video.

The given type can be either `:mp4`, `:ogg`, `:avi`, `:wmv`, `:mov`
or a string with video MIME type.

## Options

  * `:autoplay` - whether the video should start playing as soon as
    it is rendered. Defaults to `false`

  * `:loop` - whether the video should loop. Defaults to `false`

  * `:muted` - whether the video should be muted. Defaults to `false`