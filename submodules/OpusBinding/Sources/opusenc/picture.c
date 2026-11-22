/* Copyright (C)2007-2013 Xiph.Org Foundation
   File: picture.c

   Redistribution and use in source and binary forms, with or without
   modification, are permitted provided that the following conditions
   are met:

   - Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.

   - Redistributions in binary form must reproduce the above copyright
   notice, this list of conditions and the following disclaimer in the
   documentation and/or other materials provided with the distribution.

   THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
   ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
   LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
   A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE FOUNDATION OR
   CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
   EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
   PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
   PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
   LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
   NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
   SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

#ifdef HAVE_CONFIG_H
# include "config.h"
#endif

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "picture.h"

static const char BASE64_TABLE[64]={
  'A','B','C','D','E','F','G','H','I','J','K','L','M','N','O','P',
  'Q','R','S','T','U','V','W','X','Y','Z','a','b','c','d','e','f',
  'g','h','i','j','k','l','m','n','o','p','q','r','s','t','u','v',
  'w','x','y','z','0','1','2','3','4','5','6','7','8','9','+','/'
};

/*Utility function for base64 encoding METADATA_BLOCK_PICTURE tags.
  Stores BASE64_LENGTH(len)+1 bytes in dst (including a terminating NUL).*/
void base64_encode(char *dst, const char *src, int len){
  unsigned s0;
  unsigned s1;
  unsigned s2;
  int      ngroups;
  int      i;
  ngroups=len/3;
  for(i=0;i<ngroups;i++){
    s0=(unsigned char)src[3*i+0];
    s1=(unsigned char)src[3*i+1];
    s2=(unsigned char)src[3*i+2];
    dst[4*i+0]=BASE64_TABLE[s0>>2];
    dst[4*i+1]=BASE64_TABLE[(s0&3)<<4|s1>>4];
    dst[4*i+2]=BASE64_TABLE[(s1&15)<<2|s2>>6];
    dst[4*i+3]=BASE64_TABLE[s2&63];
  }
  len-=3*i;
  if(len==1){
    s0=(unsigned char)src[3*i+0];
    dst[4*i+0]=BASE64_TABLE[s0>>2];
    dst[4*i+1]=BASE64_TABLE[(s0&3)<<4];
    dst[4*i+2]='=';
    dst[4*i+3]='=';
    i++;
  }
  else if(len==2){
    s0=(unsigned char)src[3*i+0];
    s1=(unsigned char)src[3*i+1];
    dst[4*i+0]=BASE64_TABLE[s0>>2];
    dst[4*i+1]=BASE64_TABLE[(s0&3)<<4|s1>>4];
    dst[4*i+2]=BASE64_TABLE[(s1&15)<<2];
    dst[4*i+3]='=';
    i++;
  }
  dst[4*i]='\0';
}

/*A version of strncasecmp() that is guaranteed to only ignore the case of
   ASCII characters.*/
int oi_strncasecmp(const char *a, const char *b, int n){
  int i;
  for(i=0;i<n;i++){
    int aval;
    int bval;
    int diff;
    aval=a[i];
    bval=b[i];
    if(aval>='a'&&aval<='z') {
      aval-='a'-'A';
    }
    if(bval>='a'&&bval<='z'){
      bval-='a'-'A';
    }
    diff=aval-bval;
    if(diff){
      return diff;
    }
  }
  return 0;
}

int is_jpeg(const unsigned char *buf, size_t length){
  return length>=11&&memcmp(buf,"\xFF\xD8\xFF\xE0",4)==0
   &&(buf[4]<<8|buf[5])>=16&&memcmp(buf+6,"JFIF",5)==0;
}

int is_png(const unsigned char *buf, size_t length){
  return length>=8&&memcmp(buf,"\x89PNG\x0D\x0A\x1A\x0A",8)==0;
}

int is_gif(const unsigned char *buf, size_t length){
  return length>=6
   &&(memcmp(buf,"GIF87a",6)==0||memcmp(buf,"GIF89a",6)==0);
}

#define READ_U32_BE(buf) \
    (((buf)[0]<<24)|((buf)[1]<<16)|((buf)[2]<<8)|((buf)[3]&0xff))

/*Tries to extract the width, height, bits per pixel, and palette size of a
   PNG.
  On failure, simply leaves its outputs unmodified.*/
void extract_png_params(const unsigned char *data, size_t data_length,
                        ogg_uint32_t *width, ogg_uint32_t *height,
                        ogg_uint32_t *depth, ogg_uint32_t *colors,
                        int *has_palette){
  if(is_png(data,data_length)){
    size_t offs;
    offs=8;
    while(data_length-offs>=12){
      ogg_uint32_t chunk_len;
      chunk_len=READ_U32_BE(data+offs);
      if(chunk_len>data_length-(offs+12))break;
      else if(chunk_len==13&&memcmp(data+offs+4,"IHDR",4)==0){
        int color_type;
        *width=READ_U32_BE(data+offs+8);
        *height=READ_U32_BE(data+offs+12);
        color_type=data[offs+17];
        if(color_type==3){
          *depth=24;
          *has_palette=1;
        }
        else{
          int sample_depth;
          sample_depth=data[offs+16];
          if(color_type==0)*depth=sample_depth;
          else if(color_type==2)*depth=sample_depth*3;
          else if(color_type==4)*depth=sample_depth*2;
          else if(color_type==6)*depth=sample_depth*4;
          *colors=0;
          *has_palette=0;
          break;
        }
      }
      else if(*has_palette>0&&memcmp(data+offs+4,"PLTE",4)==0){
        *colors=chunk_len/3;
        break;
      }
      offs+=12+chunk_len;
    }
  }
}

/*Tries to extract the width, height, bits per pixel, and palette size of a
   GIF.
  On failure, simply leaves its outputs unmodified.*/
void extract_gif_params(const unsigned char *data, size_t data_length,
                        ogg_uint32_t *width, ogg_uint32_t *height,
                        ogg_uint32_t *depth, ogg_uint32_t *colors,
                        int *has_palette){
  if(is_gif(data,data_length)&&data_length>=14){
    *width=data[6]|data[7]<<8;
    *height=data[8]|data[9]<<8;
    /*libFLAC hard-codes the depth to 24.*/
    *depth=24;
    *colors=1<<((data[10]&7)+1);
    *has_palette=1;
  }
}


/*Tries to extract the width, height, bits per pixel, and palette size of a
   JPEG.
  On failure, simply leaves its outputs unmodified.*/
void extract_jpeg_params(const unsigned char *data, size_t data_length,
                         ogg_uint32_t *width, ogg_uint32_t *height,
                         ogg_uint32_t *depth, ogg_uint32_t *colors,
                         int *has_palette){
  if(is_jpeg(data,data_length)){
    size_t offs;
    offs=2;
    for(;;){
      size_t segment_len;
      int    marker;
      while(offs<data_length&&data[offs]!=0xFF)offs++;
      while(offs<data_length&&data[offs]==0xFF)offs++;
      marker=data[offs];
      offs++;
      /*If we hit EOI* (end of image), or another SOI* (start of image),
         or SOS (start of scan), then stop now.*/
      if(offs>=data_length||(marker>=0xD8&&marker<=0xDA))break;
      /*RST* (restart markers): skip (no segment length).*/
      else if(marker>=0xD0&&marker<=0xD7)continue;
      /*Read the length of the marker segment.*/
      if(data_length-offs<2)break;
      segment_len=data[offs]<<8|data[offs+1];
      if(segment_len<2||data_length-offs<segment_len)break;
      if(marker==0xC0||(marker>0xC0&&marker<0xD0&&(marker&3)!=0)){
        /*Found a SOFn (start of frame) marker segment:*/
        if(segment_len>=8){
          *height=data[offs+3]<<8|data[offs+4];
          *width=data[offs+5]<<8|data[offs+6];
          *depth=data[offs+2]*data[offs+7];
          *colors=0;
          *has_palette=0;
        }
        break;
      }
      /*Other markers: skip the whole marker segment.*/
      offs+=segment_len;
    }
  }
}

#define IMAX(a,b) ((a) > (b) ? (a) : (b))

/*Parse a picture SPECIFICATION as given on the command-line.
  spec: The specification.
  error_message: Returns an error message on error.
  seen_file_icons: Bit flags used to track if any pictures of type 1 or type 2
   have already been added, to ensure only one is allowed.
  Return: A Base64-encoded string suitable for use in a METADATA_BLOCK_PICTURE
   tag.*/
char *parse_picture_specification(const char *spec,
                                  const char **error_message,
                                  int *seen_file_icons){
  FILE          *picture_file;
  unsigned long  picture_type;
  unsigned long  width;
  unsigned long  height;
  unsigned long  depth;
  unsigned long  colors;
  const char    *mime_type;
  const char    *mime_type_end;
  const char    *description;
  const char    *description_end;
  const char    *filename;
  unsigned char *buf;
  char          *out;
  size_t         cbuf;
  size_t         nbuf;
  size_t         data_offset;
  size_t         data_length;
  size_t         b64_length;
  int            is_url;
  /*If a filename has a '|' in it, there's no way we can distinguish it from a
     full specification just from the spec string.
    Instead, try to open the file.
    If it exists, the user probably meant the file.*/
  picture_type=3;
  width=height=depth=colors=0;
  mime_type=mime_type_end=description=description_end=filename=spec;
  is_url=0;
  picture_file=fopen(filename,"rb");
  if(picture_file==NULL&&strchr(spec,'|')){
    const char *p;
    char       *q;
    /*We don't have a plain file, and there is a pipe character: assume it's
       the full form of the specification.*/
    picture_type=strtoul(spec,&q,10);
    if(*q!='|'||picture_type>20){
      *error_message="invalid picture type";
      return NULL;
    }
    if(picture_type>=1&&picture_type<=2&&(*seen_file_icons&picture_type)){
      *error_message=picture_type==1?
       "only one picture of type 1 (32x32 icon) allowed":
       "only one picture of type 2 (icon) allowed";
      return NULL;
    }
    /*An empty field implies a default of 'Cover (front)'.*/
    if(spec==q)picture_type=3;
    mime_type=q+1;
    mime_type_end=mime_type+strcspn(mime_type,"|");
    if(*mime_type_end!='|'){
      *error_message="invalid picture specification: not enough fields";
      return NULL;
    }
    /*The mime type must be composed of ASCII printable characters 0x20-0x7E.*/
    for(p=mime_type;p<mime_type_end;p++)if(*p<0x20||*p>0x7E){
      *error_message="invalid characters in mime type";
      return NULL;
    }
    is_url=mime_type_end-mime_type==3
     &&strncmp("-->",mime_type,mime_type_end-mime_type)==0;
    description=mime_type_end+1;
    description_end=description+strcspn(description,"|");
    if(*description_end!='|'){
      *error_message="invalid picture specification: not enough fields";
      return NULL;
    }
    p=description_end+1;
    if(*p!='|'){
      width=strtoul(p,&q,10);
      if(*q!='x'){
        *error_message=
         "invalid picture specification: can't parse resolution/color field";
        return NULL;
      }
      p=q+1;
      height=strtoul(p,&q,10);
      if(*q!='x'){
        *error_message=
         "invalid picture specification: can't parse resolution/color field";
        return NULL;
      }
      p=q+1;
      depth=strtoul(p,&q,10);
      if(*q=='/'){
        p=q+1;
        colors=strtoul(p,&q,10);
      }
      if(*q!='|'){
        *error_message=
         "invalid picture specification: can't parse resolution/color field";
        return NULL;
      }
      p=q;
    }
    filename=p+1;
    if(!is_url)picture_file=fopen(filename,"rb");
  }
  /*Buffer size: 8 static 4-byte fields plus 2 dynamic fields, plus the
     file/URL data.
    We reserve at least 10 bytes for the mime type, in case we still need to
     extract it from the file.*/
  data_offset=32+(description_end-description)+IMAX(mime_type_end-mime_type,10);
  buf=NULL;
  if(is_url){
    /*Easy case: just stick the URL at the end.
      We don't do anything to verify it's a valid URL.*/
    data_length=strlen(filename);
    cbuf=nbuf=data_offset+data_length;
    buf=(unsigned char *)malloc(cbuf);
    memcpy(buf+data_offset,filename,data_length);
  }
  else{
    ogg_uint32_t file_width;
    ogg_uint32_t file_height;
    ogg_uint32_t file_depth;
    ogg_uint32_t file_colors;
    int          has_palette;
    /*Complicated case: we have a real file.
      Read it in, attempt to parse the mime type and image dimensions if
       necessary, and validate what the user passed in.*/
    if(picture_file==NULL){
      *error_message="error opening picture file";
      return NULL;
    }
    nbuf=data_offset;
    /*Add a reasonable starting image file size.*/
    cbuf=data_offset+65536;
    for(;;){
      unsigned char *new_buf;
      size_t         nread;
      new_buf=realloc(buf,cbuf);
      if(new_buf==NULL){
        fclose(picture_file);
        free(buf);
        *error_message="insufficient memory";
        return NULL;
      }
      buf=new_buf;
      nread=fread(buf+nbuf,1,cbuf-nbuf,picture_file);
      nbuf+=nread;
      if(nbuf<cbuf){
        int error;
        error=ferror(picture_file);
        fclose(picture_file);
        if(error){
          free(buf);
          *error_message="error reading picture file";
          return NULL;
        }
        break;
      }
      if(cbuf==0xFFFFFFFF){
        fclose(picture_file);
        free(buf);
        *error_message="file too large";
        return NULL;
      }
      else if(cbuf>0x7FFFFFFFU)cbuf=0xFFFFFFFFU;
      else cbuf=cbuf<<1|1;
    }
    data_length=nbuf-data_offset;
    /*If there was no mimetype, try to extract it from the file data.*/
    if(mime_type_end==mime_type){
      if(is_jpeg(buf+data_offset,data_length)){
        mime_type="image/jpeg";
        mime_type_end=mime_type+10;
      }
      else if(is_png(buf+data_offset,data_length)){
        mime_type="image/png";
        mime_type_end=mime_type+9;
      }
      else if(is_gif(buf+data_offset,data_length)){
        mime_type="image/gif";
        mime_type_end=mime_type+9;
      }
      else{
        free(buf);
        *error_message="unable to guess MIME type from file, "
         "must set it explicitly";
        return NULL;
      }
    }
    /*Try to extract the image dimensions/color information from the file.*/
    file_width=file_height=file_depth=file_colors=0;
    has_palette=-1;
    if(mime_type_end-mime_type==9
     &&oi_strncasecmp("image/png",mime_type,mime_type_end-mime_type)==0){
      extract_png_params(buf+data_offset,data_length,
       &file_width,&file_height,&file_depth,&file_colors,&has_palette);
    }
    else if(mime_type_end-mime_type==9
     &&oi_strncasecmp("image/gif",mime_type,mime_type_end-mime_type)==0){
      extract_gif_params(buf+data_offset,data_length,
       &file_width,&file_height,&file_depth,&file_colors,&has_palette);
    }
    else if(mime_type_end-mime_type==10
     &&oi_strncasecmp("image/jpeg",mime_type,mime_type_end-mime_type)==0){
      extract_jpeg_params(buf+data_offset,data_length,
       &file_width,&file_height,&file_depth,&file_colors,&has_palette);
    }
    if(!width)width=file_width;
    if(!height)height=file_height;
    if(!depth)depth=file_depth;
    if(!colors)colors=file_colors;
    if((file_width&&width!=file_width)
     ||(file_height&&height!=file_height)
     ||(file_depth&&depth!=file_depth)
     /*We use has_palette to ensure we also reject non-0 user color counts for
        images we've positively identified as non-paletted.*/
     ||(has_palette>=0&&colors!=file_colors)){
      free(buf);
      *error_message="invalid picture specification: "
       "resolution/color field does not match file";
      return NULL;
    }
  }
  /*These fields MUST be set correctly OR all set to zero.
    So if any of them (except colors, for which 0 is a valid value) are still
     zero, clear the rest to zero.*/
  if(width==0||height==0||depth==0)width=height=depth=colors=0;
  if(picture_type==1&&(width!=32||height!=32
   ||mime_type_end-mime_type!=9
   ||oi_strncasecmp("image/png",mime_type,mime_type_end-mime_type)!=0)){
    free(buf);
    *error_message="pictures of type 1 MUST be 32x32 PNGs";
    return NULL;
  }
  /*Build the METADATA_BLOCK_PICTURE buffer.
    We do this backwards from data_offset, because we didn't necessarily know
     how big the mime type string was before we read the data in.*/
  data_offset-=4;
  WRITE_U32_BE(buf+data_offset,(unsigned long)data_length);
  data_offset-=4;
  WRITE_U32_BE(buf+data_offset,colors);
  data_offset-=4;
  WRITE_U32_BE(buf+data_offset,depth);
  data_offset-=4;
  WRITE_U32_BE(buf+data_offset,height);
  data_offset-=4;
  WRITE_U32_BE(buf+data_offset,width);
  data_offset-=description_end-description;
  memcpy(buf+data_offset,description,description_end-description);
  data_offset-=4;
  WRITE_U32_BE(buf+data_offset,(unsigned long)(description_end-description));
  data_offset-=mime_type_end-mime_type;
  memcpy(buf+data_offset,mime_type,mime_type_end-mime_type);
  data_offset-=4;
  WRITE_U32_BE(buf+data_offset,(unsigned long)(mime_type_end-mime_type));
  data_offset-=4;
  WRITE_U32_BE(buf+data_offset,picture_type);
  data_length=nbuf-data_offset;
  b64_length=BASE64_LENGTH(data_length);
  out=(char *)malloc(b64_length+1);
  if(out!=NULL){
    base64_encode(out,(char *)buf+data_offset,data_length);
    if(picture_type>=1&&picture_type<=2)*seen_file_icons|=picture_type;
  }
  free(buf);
  return out;
}
