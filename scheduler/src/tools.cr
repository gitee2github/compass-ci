module Public
    def self.hash_replace_with(hash_in : Hash, hash_r : Hash)
        keyname = hash_r.keys[0]

        if hash_in[keyname]?
            hash_in.delete(keyname)
        end

        return hash_r.merge(hash_in)
    end

    def self.get_tbox_group_name(testbox : String)
        tbox_group = testbox

        find = testbox.match(/(.*)(\-\d{1,}$)/)
        if find != nil
            tbox_group = find.not_nil![1]
        end

        return tbox_group
    end
end
