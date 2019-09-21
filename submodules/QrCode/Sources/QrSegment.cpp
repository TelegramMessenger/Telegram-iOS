/* 
 * QR Code generator library (C++)
 * 
 * Copyright (c) Project Nayuki. (MIT License)
 * https://www.nayuki.io/page/qr-code-generator-library
 * 
 * Permission is hereby granted, free of charge, to any person obtaining a copy of
 * this software and associated documentation files (the "Software"), to deal in
 * the Software without restriction, including without limitation the rights to
 * use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
 * the Software, and to permit persons to whom the Software is furnished to do so,
 * subject to the following conditions:
 * - The above copyright notice and this permission notice shall be included in
 *   all copies or substantial portions of the Software.
 * - The Software is provided "as is", without warranty of any kind, express or
 *   implied, including but not limited to the warranties of merchantability,
 *   fitness for a particular purpose and noninfringement. In no event shall the
 *   authors or copyright holders be liable for any claim, damages or other
 *   liability, whether in an action of contract, tort or otherwise, arising from,
 *   out of or in connection with the Software or the use or other dealings in the
 *   Software.
 */

#include <climits>
#include <cstring>
#include <stdexcept>
#include <utility>
#include "QrSegment.hpp"

using std::uint8_t;
using std::vector;


namespace qrcodegen {

QrSegment::Mode::Mode(int mode, int cc0, int cc1, int cc2) :
		modeBits(mode) {
	numBitsCharCount[0] = cc0;
	numBitsCharCount[1] = cc1;
	numBitsCharCount[2] = cc2;
}


int QrSegment::Mode::getModeBits() const {
	return modeBits;
}


int QrSegment::Mode::numCharCountBits(int ver) const {
	return numBitsCharCount[(ver + 7) / 17];
}


const QrSegment::Mode QrSegment::Mode::NUMERIC     (0x1, 10, 12, 14);
const QrSegment::Mode QrSegment::Mode::ALPHANUMERIC(0x2,  9, 11, 13);
const QrSegment::Mode QrSegment::Mode::BYTE        (0x4,  8, 16, 16);
const QrSegment::Mode QrSegment::Mode::KANJI       (0x8,  8, 10, 12);
const QrSegment::Mode QrSegment::Mode::ECI         (0x7,  0,  0,  0);



QrSegment QrSegment::makeBytes(const vector<uint8_t> &data) {
	if (data.size() > static_cast<unsigned int>(INT_MAX))
		throw std::length_error("Data too long");
	BitBuffer bb;
	for (uint8_t b : data)
		bb.appendBits(b, 8);
	return QrSegment(Mode::BYTE, static_cast<int>(data.size()), std::move(bb));
}


QrSegment QrSegment::makeNumeric(const char *digits) {
	BitBuffer bb;
	int accumData = 0;
	int accumCount = 0;
	int charCount = 0;
	for (; *digits != '\0'; digits++, charCount++) {
		char c = *digits;
		if (c < '0' || c > '9')
			throw std::domain_error("String contains non-numeric characters");
		accumData = accumData * 10 + (c - '0');
		accumCount++;
		if (accumCount == 3) {
			bb.appendBits(static_cast<uint32_t>(accumData), 10);
			accumData = 0;
			accumCount = 0;
		}
	}
	if (accumCount > 0)  // 1 or 2 digits remaining
		bb.appendBits(static_cast<uint32_t>(accumData), accumCount * 3 + 1);
	return QrSegment(Mode::NUMERIC, charCount, std::move(bb));
}


QrSegment QrSegment::makeAlphanumeric(const char *text) {
	BitBuffer bb;
	int accumData = 0;
	int accumCount = 0;
	int charCount = 0;
	for (; *text != '\0'; text++, charCount++) {
		const char *temp = std::strchr(ALPHANUMERIC_CHARSET, *text);
		if (temp == nullptr)
			throw std::domain_error("String contains unencodable characters in alphanumeric mode");
		accumData = accumData * 45 + static_cast<int>(temp - ALPHANUMERIC_CHARSET);
		accumCount++;
		if (accumCount == 2) {
			bb.appendBits(static_cast<uint32_t>(accumData), 11);
			accumData = 0;
			accumCount = 0;
		}
	}
	if (accumCount > 0)  // 1 character remaining
		bb.appendBits(static_cast<uint32_t>(accumData), 6);
	return QrSegment(Mode::ALPHANUMERIC, charCount, std::move(bb));
}


vector<QrSegment> QrSegment::makeSegments(const char *text) {
	// Select the most efficient segment encoding automatically
	vector<QrSegment> result;
	if (*text == '\0');  // Leave result empty
	else if (isNumeric(text))
		result.push_back(makeNumeric(text));
	else if (isAlphanumeric(text))
		result.push_back(makeAlphanumeric(text));
	else {
		vector<uint8_t> bytes;
		for (; *text != '\0'; text++)
			bytes.push_back(static_cast<uint8_t>(*text));
		result.push_back(makeBytes(bytes));
	}
	return result;
}


QrSegment QrSegment::makeEci(long assignVal) {
	BitBuffer bb;
	if (assignVal < 0)
		throw std::domain_error("ECI assignment value out of range");
	else if (assignVal < (1 << 7))
		bb.appendBits(static_cast<uint32_t>(assignVal), 8);
	else if (assignVal < (1 << 14)) {
		bb.appendBits(2, 2);
		bb.appendBits(static_cast<uint32_t>(assignVal), 14);
	} else if (assignVal < 1000000L) {
		bb.appendBits(6, 3);
		bb.appendBits(static_cast<uint32_t>(assignVal), 21);
	} else
		throw std::domain_error("ECI assignment value out of range");
	return QrSegment(Mode::ECI, 0, std::move(bb));
}


QrSegment::QrSegment(Mode md, int numCh, const std::vector<bool> &dt) :
		mode(md),
		numChars(numCh),
		data(dt) {
	if (numCh < 0)
		throw std::domain_error("Invalid value");
}


QrSegment::QrSegment(Mode md, int numCh, std::vector<bool> &&dt) :
		mode(md),
		numChars(numCh),
		data(std::move(dt)) {
	if (numCh < 0)
		throw std::domain_error("Invalid value");
}


int QrSegment::getTotalBits(const vector<QrSegment> &segs, int version) {
	int result = 0;
	for (const QrSegment &seg : segs) {
		int ccbits = seg.mode.numCharCountBits(version);
		if (seg.numChars >= (1L << ccbits))
			return -1;  // The segment's length doesn't fit the field's bit width
		if (4 + ccbits > INT_MAX - result)
			return -1;  // The sum will overflow an int type
		result += 4 + ccbits;
		if (seg.data.size() > static_cast<unsigned int>(INT_MAX - result))
			return -1;  // The sum will overflow an int type
		result += static_cast<int>(seg.data.size());
	}
	return result;
}


bool QrSegment::isAlphanumeric(const char *text) {
	for (; *text != '\0'; text++) {
		if (std::strchr(ALPHANUMERIC_CHARSET, *text) == nullptr)
			return false;
	}
	return true;
}


bool QrSegment::isNumeric(const char *text) {
	for (; *text != '\0'; text++) {
		char c = *text;
		if (c < '0' || c > '9')
			return false;
	}
	return true;
}


QrSegment::Mode QrSegment::getMode() const {
	return mode;
}


int QrSegment::getNumChars() const {
	return numChars;
}


const std::vector<bool> &QrSegment::getData() const {
	return data;
}


const char *QrSegment::ALPHANUMERIC_CHARSET = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ $%*+-./:";

}
