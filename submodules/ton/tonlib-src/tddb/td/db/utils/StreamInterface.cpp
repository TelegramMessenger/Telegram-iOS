/*
    This file is part of TON Blockchain Library.

    TON Blockchain Library is free software: you can redistribute it and/or modify
    it under the terms of the GNU Lesser General Public License as published by
    the Free Software Foundation, either version 2 of the License, or
    (at your option) any later version.

    TON Blockchain Library is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Lesser General Public License for more details.

    You should have received a copy of the GNU Lesser General Public License
    along with TON Blockchain Library.  If not, see <http://www.gnu.org/licenses/>.

    Copyright 2017-2019 Telegram Systems LLP
*/
#include "StreamInterface.h"
namespace td {
StreamReader::StreamReader(std::shared_ptr<StreamReaderInterface> self) : self(std::move(self)) {
}
size_t StreamReader::reader_size() {
  return self->reader_size();
}
Slice StreamReader::prepare_read() {
  return self->prepare_read();
}
Span<IoSlice> StreamReader::prepare_readv() {
  return self->prepare_readv();
}
void StreamReader::confirm_read(size_t size) {
  return self->confirm_read(size);
}

void StreamReader::close_reader(Status error) {
  return self->close_reader(std::move(error));
}
bool StreamReader::is_writer_closed() const {
  return self->is_writer_closed();
}
Status &StreamReader::writer_status() {
  return self->writer_status();
}

StreamWriter::StreamWriter(std::shared_ptr<StreamWriterInterface> self) : self(std::move(self)) {
}
size_t StreamWriter::writer_size() {
  return self->writer_size();
}
MutableSlice StreamWriter::prepare_write() {
  return self->prepare_write();
}
MutableSlice StreamWriter::prepare_write_at_least(size_t size) {
  return self->prepare_write_at_least(size);
}
void StreamWriter::confirm_write(size_t size) {
  return self->confirm_write(size);
}
void StreamWriter::append(Slice data) {
  return self->append(data);
}
void StreamWriter::append(BufferSlice data) {
  return self->append(std::move(data));
}
void StreamWriter::append(std::string data) {
  return self->append(std::move(data));
}

void StreamWriter::close_writer(Status error) {
  return self->close_writer(std::move(error));
}
bool StreamWriter::is_reader_closed() const {
  return self->is_reader_closed();
}
Status &StreamWriter::reader_status() {
  return self->reader_status();
}
}  // namespace td
