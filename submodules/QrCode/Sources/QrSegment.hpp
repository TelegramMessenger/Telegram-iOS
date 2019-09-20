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

#pragma once

#include <cstdint>
#include <vector>
#include "BitBuffer.hpp"


namespace qrcodegen {

/* 
 * A segment of character/binary/control data in a QR Code symbol.
 * Instances of this class are immutable.
 * The mid-level way to create a segment is to take the payload data
 * and call a static factory function such as QrSegment::makeNumeric().
 * The low-level way to create a segment is to custom-make the bit buffer
 * and call the QrSegment() constructor with appropriate values.
 * This segment class imposes no length restrictions, but QR Codes have restrictions.
 * Even in the most favorable conditions, a QR Code can only hold 7089 characters of data.
 * Any segment longer than this is meaningless for the purpose of generating QR Codes.
 */
class QrSegment final {
	
	/*---- Public helper enumeration ----*/
	
	/* 
	 * Describes how a segment's data bits are interpreted. Immutable.
	 */
	public: class Mode final {
		
		/*-- Constants --*/
		
		public: static const Mode NUMERIC;
		public: static const Mode ALPHANUMERIC;
		public: static const Mode BYTE;
		public: static const Mode KANJI;
		public: static const Mode ECI;
		
		
		/*-- Fields --*/
		
		// The mode indicator bits, which is a uint4 value (range 0 to 15).
		private: int modeBits;
		
		// Number of character count bits for three different version ranges.
		private: int numBitsCharCount[3];
		
		
		/*-- Constructor --*/
		
		private: Mode(int mode, int cc0, int cc1, int cc2);
		
		
		/*-- Methods --*/
		
		/* 
		 * (Package-private) Returns the mode indicator bits, which is an unsigned 4-bit value (range 0 to 15).
		 */
		public: int getModeBits() const;
		
		/* 
		 * (Package-private) Returns the bit width of the character count field for a segment in
		 * this mode in a QR Code at the given version number. The result is in the range [0, 16].
		 */
		public: int numCharCountBits(int ver) const;
		
	};
	
	
	
	/*---- Static factory functions (mid level) ----*/
	
	/* 
	 * Returns a segment representing the given binary data encoded in
	 * byte mode. All input byte vectors are acceptable. Any text string
	 * can be converted to UTF-8 bytes and encoded as a byte mode segment.
	 */
	public: static QrSegment makeBytes(const std::vector<std::uint8_t> &data);
	
	
	/* 
	 * Returns a segment representing the given string of decimal digits encoded in numeric mode.
	 */
	public: static QrSegment makeNumeric(const char *digits);
	
	
	/* 
	 * Returns a segment representing the given text string encoded in alphanumeric mode.
	 * The characters allowed are: 0 to 9, A to Z (uppercase only), space,
	 * dollar, percent, asterisk, plus, hyphen, period, slash, colon.
	 */
	public: static QrSegment makeAlphanumeric(const char *text);
	
	
	/* 
	 * Returns a list of zero or more segments to represent the given text string. The result
	 * may use various segment modes and switch modes to optimize the length of the bit stream.
	 */
	public: static std::vector<QrSegment> makeSegments(const char *text);
	
	
	/* 
	 * Returns a segment representing an Extended Channel Interpretation
	 * (ECI) designator with the given assignment value.
	 */
	public: static QrSegment makeEci(long assignVal);
	
	
	/*---- Public static helper functions ----*/
	
	/* 
	 * Tests whether the given string can be encoded as a segment in alphanumeric mode.
	 * A string is encodable iff each character is in the following set: 0 to 9, A to Z
	 * (uppercase only), space, dollar, percent, asterisk, plus, hyphen, period, slash, colon.
	 */
	public: static bool isAlphanumeric(const char *text);
	
	
	/* 
	 * Tests whether the given string can be encoded as a segment in numeric mode.
	 * A string is encodable iff each character is in the range 0 to 9.
	 */
	public: static bool isNumeric(const char *text);
	
	
	
	/*---- Instance fields ----*/
	
	/* The mode indicator of this segment. Accessed through getMode(). */
	private: Mode mode;
	
	/* The length of this segment's unencoded data. Measured in characters for
	 * numeric/alphanumeric/kanji mode, bytes for byte mode, and 0 for ECI mode.
	 * Always zero or positive. Not the same as the data's bit length.
	 * Accessed through getNumChars(). */
	private: int numChars;
	
	/* The data bits of this segment. Accessed through getData(). */
	private: std::vector<bool> data;
	
	
	/*---- Constructors (low level) ----*/
	
	/* 
	 * Creates a new QR Code segment with the given attributes and data.
	 * The character count (numCh) must agree with the mode and the bit buffer length,
	 * but the constraint isn't checked. The given bit buffer is copied and stored.
	 */
	public: QrSegment(Mode md, int numCh, const std::vector<bool> &dt);
	
	
	/* 
	 * Creates a new QR Code segment with the given parameters and data.
	 * The character count (numCh) must agree with the mode and the bit buffer length,
	 * but the constraint isn't checked. The given bit buffer is moved and stored.
	 */
	public: QrSegment(Mode md, int numCh, std::vector<bool> &&dt);
	
	
	/*---- Methods ----*/
	
	/* 
	 * Returns the mode field of this segment.
	 */
	public: Mode getMode() const;
	
	
	/* 
	 * Returns the character count field of this segment.
	 */
	public: int getNumChars() const;
	
	
	/* 
	 * Returns the data bits of this segment.
	 */
	public: const std::vector<bool> &getData() const;
	
	
	// (Package-private) Calculates the number of bits needed to encode the given segments at
	// the given version. Returns a non-negative number if successful. Otherwise returns -1 if a
	// segment has too many characters to fit its length field, or the total bits exceeds INT_MAX.
	public: static int getTotalBits(const std::vector<QrSegment> &segs, int version);
	
	
	/*---- Private constant ----*/
	
	/* The set of all legal characters in alphanumeric mode, where
	 * each character value maps to the index in the string. */
	private: static const char *ALPHANUMERIC_CHARSET;
	
};

}
