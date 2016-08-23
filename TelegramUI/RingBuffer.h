#import <Foundation/Foundation.h>

#include <string.h>
#include <assert.h>

#ifdef __cplusplus
extern "C" {
#endif
    
    typedef struct {
        void             *buffer;
        int32_t           length;
        int32_t           tail;
        int32_t           head;
        int32_t  fillCount;
    } TPCircularBuffer;
    
    /*!
     * Initialise buffer
     *
     *  Note that the length is advisory only: Because of the way the
     *  memory mirroring technique works, the true buffer length will
     *  be multiples of the device page size (e.g. 4096 bytes)
     *
     *  If you intend to use the AudioBufferList utilities, you should
     *  always allocate a bit more space than you need for pure audio
     *  data, so there's room for the metadata. How much extra is required
     *  depends on how many AudioBufferList structures are used, which is
     *  a function of how many audio frames each buffer holds. A good rule
     *  of thumb is to add 15%, or at least another 2048 bytes or so.
     *
     * @param buffer Circular buffer
     * @param length Length of buffer
     */
    bool TPCircularBufferInit(TPCircularBuffer *buffer, int32_t length);
    bool _TPCircularBufferInit(TPCircularBuffer *buffer, int32_t length, size_t structSize);
    
    /*!
     * Cleanup buffer
     *
     *  Releases buffer resources.
     */
    void  TPCircularBufferCleanup(TPCircularBuffer *buffer);
    
    /*!
     * Clear buffer
     *
     *  Resets buffer to original, empty state.
     *
     *  This is safe for use by consumer while producer is accessing
     *  buffer.
     */
    void  TPCircularBufferClear(TPCircularBuffer *buffer);
    
    // Reading (consuming)
    
    /*!
     * Access end of buffer
     *
     *  This gives you a pointer to the end of the buffer, ready
     *  for reading, and the number of available bytes to read.
     *
     * @param buffer Circular buffer
     * @param availableBytes On output, the number of bytes ready for reading
     * @return Pointer to the first bytes ready for reading, or NULL if buffer is empty
     */
    static __inline__ __attribute__((always_inline)) void* TPCircularBufferTail(TPCircularBuffer *buffer, int32_t* availableBytes) {
        *availableBytes = buffer->fillCount;
        if ( *availableBytes == 0 ) return NULL;
        return (void*)((char*)buffer->buffer + buffer->tail);
    }
    
    /*!
     * Consume bytes in buffer
     *
     *  This frees up the just-read bytes, ready for writing again.
     *
     * @param buffer Circular buffer
     * @param amount Number of bytes to consume
     */
    static __inline__ __attribute__((always_inline)) void TPCircularBufferConsume(TPCircularBuffer *buffer, int32_t amount) {
        buffer->tail = (buffer->tail + amount) % buffer->length;
        buffer->fillCount -= amount;
        assert(buffer->fillCount >= 0);
    }
    
    /*!
     * Access front of buffer
     *
     *  This gives you a pointer to the front of the buffer, ready
     *  for writing, and the number of available bytes to write.
     *
     * @param buffer Circular buffer
     * @param availableBytes On output, the number of bytes ready for writing
     * @return Pointer to the first bytes ready for writing, or NULL if buffer is full
     */
    static __inline__ __attribute__((always_inline)) void* TPCircularBufferHead(TPCircularBuffer *buffer, int32_t* availableBytes) {
        *availableBytes = (buffer->length - buffer->fillCount);
        if ( *availableBytes == 0 ) return NULL;
        return (void*)((char*)buffer->buffer + buffer->head);
    }
    
    // Writing (producing)
    
    /*!
     * Produce bytes in buffer
     *
     *  This marks the given section of the buffer ready for reading.
     *
     * @param buffer Circular buffer
     * @param amount Number of bytes to produce
     */
    static __inline__ __attribute__((always_inline)) void TPCircularBufferProduce(TPCircularBuffer *buffer, int32_t amount) {
        buffer->head = (buffer->head + amount) % buffer->length;
        buffer->fillCount += amount;
        assert(buffer->fillCount <= buffer->length);
    }
    
    /*!
     * Helper routine to copy bytes to buffer
     *
     *  This copies the given bytes to the buffer, and marks them ready for reading.
     *
     * @param buffer Circular buffer
     * @param src Source buffer
     * @param len Number of bytes in source buffer
     * @return true if bytes copied, false if there was insufficient space
     */
    static __inline__ __attribute__((always_inline)) bool TPCircularBufferProduceBytes(TPCircularBuffer *buffer, const void* src, int32_t len) {
        int32_t space;
        void *ptr = TPCircularBufferHead(buffer, &space);
        if ( space < len ) return false;
        memcpy(ptr, src, len);
        TPCircularBufferProduce(buffer, len);
        return true;
    }
#ifdef __cplusplus
}
#endif

