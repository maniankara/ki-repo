require 'spec_helper'

describe FileFinder do
  before do
    @tester = Tester.new
    @home = KiHome.new(@tester.tmpdir)
    @info_components = @home.package_infos.add_item("info/site").mkdir.components
    binaries = @home.packages.add_item("packages/local").mkdir.components

    comp_metadata = @info_components.add_item("test/comp").mkdir.versions.add_version("13").mkdir
    comp_internal_metadata = @info_components.add_item("test/comp-internal").mkdir.versions.add_version("3").mkdir
    product_metadata = @info_components.add_item("test/product").mkdir.versions.add_version("1").mkdir
    product_internal_metadata = @info_components.add_item("test/product-internal").mkdir.versions.add_version("2").mkdir

    @comp_binary = binaries.add_item("test/comp").mkdir.versions.add_version("13").mkdir
    Tester.write_files(@comp_binary.path, "aa.txt" => "aa")
    comp_metadata.metadata.add_dependency("test/comp-internal/3,name=test,path=test,internal")
    comp_metadata.metadata.add_files(@comp_binary.path, "*").save

    comp_internal_binary = binaries.add_item("test/comp-internal").mkdir.versions.add_version("3").mkdir
    Tester.write_files(comp_internal_binary.path, "comp-internal-not-included.txt" => "aa")
    comp_internal_metadata.metadata.add_files(comp_internal_binary.path, "*").save

    @product_internal_binary = binaries.add_item("test/product-internal").mkdir.versions.add_version("2").mkdir
    Tester.write_files(@product_internal_binary.path, "foo/product-internal.txt" => "aa")
    product_internal_metadata.metadata.add_files(@product_internal_binary.path, "*").save

    product_metadata = product_metadata.metadata
    product_metadata.add_dependency("test/comp/13,name=dep-comp,path=comp")
    product_metadata.add_dependency("test/product-internal/2,name=test,path=test,internal", "operations" => [["cp", "*.txt", "dep-txt/"]])
    product_metadata.operations << ["cp", "*.txt", "product-txt/"]
    product_metadata.save
  end

  after do
    @tester.after
  end

  it "should list all files" do
    @home.version("test/product/1").find_files.file_list.should == {
        "comp/aa.txt" => @comp_binary.path("aa.txt"),
        "test/foo/product-internal.txt" => @product_internal_binary.path("foo/product-internal.txt"),
        "dep-txt/product-internal.txt" => @product_internal_binary.path("foo/product-internal.txt"),
        "product-txt/aa.txt" => @comp_binary.path("aa.txt"),
        "product-txt/product-internal.txt" => @product_internal_binary.path("foo/product-internal.txt")
    }
  end

  it "should list matching files" do
    @home.version("test/product/1").find_files("*aa*").file_list.should == {
        "comp/aa.txt" => @comp_binary.path("aa.txt"),
        "product-txt/aa.txt" => @comp_binary.path("aa.txt")
    }
  end

  it "should list matching files but not excluded" do
    @home.version("test/product/1").find_files("*.txt").exclude_files("*pro*").file_list.should == {
        "comp/aa.txt" => @comp_binary.path("aa.txt"),
        "product-txt/aa.txt" => @comp_binary.path("aa.txt")
    }
  end

  it "should exclude matching versions" do
    @home.version("test/product/1").find_files().exclude_dependencies("13").file_list.should == {
        "test/foo/product-internal.txt" => @product_internal_binary.path("foo/product-internal.txt"),
        "dep-txt/product-internal.txt" => @product_internal_binary.path("foo/product-internal.txt"),
        "product-txt/product-internal.txt" => @product_internal_binary.path("foo/product-internal.txt")
    }
    @home.version("test/product/1").find_files().exclude_dependencies("dep-comp").file_list.should == {
        "test/foo/product-internal.txt" => @product_internal_binary.path("foo/product-internal.txt"),
        "dep-txt/product-internal.txt" => @product_internal_binary.path("foo/product-internal.txt"),
        "product-txt/product-internal.txt" => @product_internal_binary.path("foo/product-internal.txt")
    }
  end
  
  it "should support dep-rm" do
    product_metadata = @info_components.add_item("main/product").mkdir.versions.add_version("1").mkdir
    product_metadata = product_metadata.metadata
    product_metadata.add_dependency("test/product/1")
    product_metadata.save
    @home.version("main/product").find_files().file_list.should == {
        "comp/aa.txt" => @comp_binary.path("aa.txt"),
        "product-txt/aa.txt" => @comp_binary.path("aa.txt"),
    }
    product_metadata.dependencies.clear
    product_metadata.add_dependency("test/product/1", "operations" => [["dep-rm", "test/comp"]])
    product_metadata.save
    @home.version("main/product").find_files.file_list.should == {
    }
    product_metadata.dependencies.clear
    product_metadata.add_dependency("test/product/1,name=foo", "operations" => [["dep-rm", "foo"]])
    product_metadata.save
    @home.version("main/product").find_files.file_list.should == {
    }
  end

  it "should raise exception if no binaries" do
    FileUtils.rm_rf(@product_internal_binary.path)
    lambda { @home.version("test/product/1").find_files.file_list }.should raise_error("Could not find binaries directory for 'test/product-internal/2'")
  end
end
