#include <mach-o/arch.h>
#include <mach-o/loader.h>
#include <mach-o/fat.h>

#include <fcntl.h>
#include <unistd.h>
#include <sys/stat.h>
#include <stdio.h>
#include <cstdio>
#include <vector>
#include <string>
#include <array>

static uint32_t funcSwap32(uint32_t input) {
    return OSSwapBigToHostInt32(input);
}

static uint32_t funcNoSwap32(uint32_t input) {
    return OSSwapLittleToHostInt32(input);
}

static bool cleanArch(std::vector<uint8_t> &archData, bool &isEncrypted) {
    uint32_t (*swap32)(uint32_t) = funcNoSwap32;
    
    uint32_t offset = 0;
    
    const struct mach_header* header = (struct mach_header*)(archData.data() + offset);
    
    switch (header->magic) {
        case MH_CIGAM:
            swap32 = funcSwap32;
        case MH_MAGIC:
            offset += sizeof(struct mach_header);
            break;
        case MH_CIGAM_64:
            swap32 = funcSwap32;
        case MH_MAGIC_64:
            offset += sizeof(struct mach_header_64);
            break;
        default:
            return nullptr;
    }
    
    uint32_t commandCount = swap32(header->ncmds);
    
    for (uint32_t i = 0; i < commandCount; i++) {
        const struct load_command* loadCommand = (const struct load_command*)(archData.data() + offset);
        uint32_t commandSize = swap32(loadCommand->cmdsize);
        
        uint32_t commandType = swap32(loadCommand->cmd);
        if (commandType == LC_CODE_SIGNATURE) {
            const struct linkedit_data_command *dataCommand = (const struct linkedit_data_command *)(archData.data() + offset);
            uint32_t dataOffset = swap32(dataCommand->dataoff);
            uint32_t dataSize = swap32(dataCommand->datasize);
            
            // account for different signature size
            memset(archData.data() + offset + offsetof(linkedit_data_command, datasize), 0, sizeof(uint32_t));
            
            // remove signature
            archData.erase(archData.begin() + dataOffset, archData.begin() + dataOffset + dataSize);
        } else if (commandType == LC_SEGMENT_64) {
            const struct segment_command_64 *segmentCommand = (const struct segment_command_64 *)(archData.data() + offset);
            std::string segmentName = std::string(segmentCommand->segname);
            if (segmentName == "__LINKEDIT") {
                // account for different signature size
                memset(archData.data() + offset + offsetof(segment_command_64, vmsize), 0, sizeof(uint32_t));
                // account for different file size because of signatures
                memset(archData.data() + offset + offsetof(segment_command_64, filesize), 0, sizeof(uint32_t));
            }
        } else if (commandType == LC_ID_DYLIB) {
            // account for dylib timestamp
            memset(archData.data() + offset + offsetof(dylib_command, dylib) + offsetof(struct dylib, timestamp), 0, sizeof(uint32_t));
        } else if (commandType == LC_UUID) {
            // account for dylib uuid
            memset(archData.data() + offset + offsetof(uuid_command, uuid), 0, 16);
        } else if (commandType == LC_ENCRYPTION_INFO_64) {
            const struct encryption_info_command_64 *encryptionInfoCommand = (const struct encryption_info_command_64 *)(archData.data() + offset);
            if (encryptionInfoCommand->cryptid != 0) {
                isEncrypted = true;
            }
            // The App Store has begun to change offsets in LC_ENCRYPTION_INFO
            memset(archData.data() + offset + offsetof(encryption_info_command_64, cryptoff), 0, sizeof(uint32_t));
            memset(archData.data() + offset + offsetof(encryption_info_command_64, cryptsize), 0, sizeof(uint32_t));
        }
        
        offset += commandSize;
    }
    
    return true;
}

static std::vector<uint8_t> parseFat(std::vector<uint8_t> const &fileData) {
    size_t offset = 0;
    
    const struct fat_header *fatHeader = (const struct fat_header *)fileData.data();
    offset += sizeof(*fatHeader);
    
    size_t initialOffset = offset;
    
    uint32_t archCount = OSSwapBigToHostInt32(fatHeader->nfat_arch);
    
    for (uint32_t i = 0; i < archCount; i++) {
        const struct fat_arch *arch = (const struct fat_arch *)(fileData.data() + offset);
        offset += sizeof(*arch);
        
        uint32_t archOffset = OSSwapBigToHostInt32(arch->offset);
        uint32_t archSize = OSSwapBigToHostInt32(arch->size);
        cpu_type_t cputype = OSSwapBigToHostInt32(arch->cputype);
        
        if (cputype == CPU_TYPE_ARM64) {
            std::vector<uint8_t> archData;
            archData.resize(archSize);
            memcpy(archData.data(), fileData.data() + archOffset, archSize);
            return archData;
        }
    }
    
    offset = initialOffset;
    
    for (uint32_t i = 0; i < archCount; i++) {
        const struct fat_arch *arch = (const struct fat_arch *)(fileData.data() + offset);
        offset += sizeof(*arch);
        
        uint32_t archOffset = OSSwapBigToHostInt32(arch->offset);
        uint32_t archSize = OSSwapBigToHostInt32(arch->size);
        cpu_type_t cputype = OSSwapBigToHostInt32(arch->cputype);
        cpu_type_t cpusubtype = OSSwapBigToHostInt32(arch->cpusubtype);
        
        if (cputype == CPU_TYPE_ARM && cpusubtype == CPU_SUBTYPE_ARM_V7K) {
            std::vector<uint8_t> archData;
            archData.resize(archSize);
            memcpy(archData.data(), fileData.data() + archOffset, archSize);
            return archData;
        }
    }
    
    return std::vector<uint8_t>();
}

static std::vector<uint8_t> parseMachO(std::vector<uint8_t> const &fileData) {
    const uint32_t *magic = (const uint32_t *)fileData.data();
    
    if (*magic == FAT_CIGAM || *magic == FAT_MAGIC) {
        return parseFat(fileData);
    } else {
        return fileData;
    }
}

static std::vector<uint8_t> readFile(std::string const &file) {
    int fd = open(file.c_str(), O_RDONLY);
    
    if (fd == -1) {
        return std::vector<uint8_t>();
    }
    
    struct stat st;
    fstat(fd, &st);
    
    std::vector<uint8_t> fileData;
    fileData.resize((size_t)st.st_size);
    read(fd, fileData.data(), (size_t)st.st_size);
    close(fd);
    
    return fileData;
}

static void writeDataToFile(std::vector<uint8_t> const &data, std::string const &path) {
    int fd = open(path.c_str(), O_RDWR | O_CREAT | O_TRUNC, S_IRUSR | S_IWUSR);
    if (fd == -1) {
        return;
    }
    
    write(fd, data.data(), data.size());
    
    close(fd);
}

static std::vector<uint8_t> stripSwiftSymbols(std::string const &file) {
    std::string command;

    command += "xcrun bitcode_strip \"";
    command += file;
    command += "\" -r -o \"";
    command += file;
    command += ".stripped\"";

    uint8_t buffer[128];

    FILE *pipe = popen(command.c_str(), "r");
    if (!pipe) {
        throw std::runtime_error("popen() failed!");
    }
    while (true) {
        size_t readBytes = fread(buffer, 1, 128, pipe);
        if (readBytes <= 0) {
            break;
        }
    }
    pclose(pipe);

    command = "";
    command += "codesign --remove-signature \"";
    command += file;
    command += ".stripped\"";

    pipe = popen(command.c_str(), "r");
    if (!pipe) {
        throw std::runtime_error("popen() failed!");
    }
    while (true) {
        size_t readBytes = fread(buffer, 1, 128, pipe);
        if (readBytes <= 0) {
            break;
        }
    }
    pclose(pipe);

    command = "";
    command += "xcrun strip -ST -o /dev/stdout \"";
    command += file;
    command += ".stripped\" 2> /dev/null";
    
    std::vector<uint8_t> result;
    pipe = popen(command.c_str(), "r");
    if (!pipe) {
        throw std::runtime_error("popen() failed!");
    }
    while (true) {
        size_t readBytes = fread(buffer, 1, 128, pipe);
        if (readBytes <= 0) {
            break;
        }
        result.insert(result.end(), buffer, buffer + readBytes);
    }
    pclose(pipe);

    command = "";
    command += "rm \"";
    command += file;
    command += ".stripped\"";

    pipe = popen(command.c_str(), "r");
    if (!pipe) {
        throw std::runtime_error("popen() failed!");
    }
    while (true) {
        size_t readBytes = fread(buffer, 1, 128, pipe);
        if (readBytes <= 0) {
            break;
        }
    }
    pclose(pipe);
    
    return result;
}

static bool endsWith(std::string const &mainStr, std::string const &toMatch) {
    if(mainStr.size() >= toMatch.size() && mainStr.compare(mainStr.size() - toMatch.size(), toMatch.size(), toMatch) == 0) {
        return true;
    } else {
        return false;
    }
}

int main(int argc, const char *argv[]) {
    if (argc != 3) {
        printf("Usage: machofilediff file1 file2\n");
        return 1;
    }
    
    std::string file1 = argv[1];
    std::string file2 = argv[2];
    
    std::vector<uint8_t> fileData1;
    if (endsWith(file1, ".dylib")) {
        fileData1 = stripSwiftSymbols(file1);
    } else {
        fileData1 = readFile(file1);
    }
    
    std::vector<uint8_t> fileData2;
    if (endsWith(file2, ".dylib")) {
        fileData2 = stripSwiftSymbols(file2);
    } else {
        fileData2 = readFile(file2);
    }
    
    std::vector<uint8_t> arch1 = parseMachO(fileData1);
    if (arch1.size() == 0) {
        printf("Couldn't parse %s\n", file1.c_str());
        return 1;
    }
    
    std::vector<uint8_t> arch2 = parseMachO(fileData2);
    if (arch2.size() == 0) {
        printf("Couldn't parse %s\n", file2.c_str());
        return 1;
    }
    
    bool arch1Encrypted = false;
    bool arch2Encrypted = false;
    cleanArch(arch1, arch1Encrypted);
    cleanArch(arch2, arch2Encrypted);
    
    if (arch1 == arch2) {
        printf("Equal\n");
        return 0;
    } else {
        if (arch1Encrypted || arch2Encrypted) {
            printf("Encrypted\n");
        } else {
            printf("Not Equal\n");
        }
        
        return 1;
    }
    
    return 0;
}
